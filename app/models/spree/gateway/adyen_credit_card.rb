module Spree
  class Gateway::AdyenCreditCard < Gateway
    class MissingTokenError < Spree::Core::GatewayError
      def message
        I18n.t(:missing_token_error, scope: 'solidus-adyen')
      end
    end

    class Authorize3DSecureError < Spree::Core::GatewayError
      def message
        I18n.t(:authorize_3d_failed, scope: 'solidus-adyen')
      end
    end

    include Spree::Gateway::AdyenGateway
    preference :cse_library_location, :string, default: ''

    def cse_library_location
      ENV["ADYEN_CSE_LIBRARY_LOCATION"] || preferred_cse_library_location
    end

    def method_type
      "adyen_encrypted_cc"
    end

    # We need to authorize Adyen credit card payments in the payment step
    # during checkout when we still have the encrypted card data. Since the
    # payment should already be authorized here, we return a dummy response.
    def authorize(amount, card, gateway_options)
      handle_response(
        perform_authorization(amount, card, gateway_options)
      )
    end

    def authorize_3d_secure_payment(payment, adyen_3d_params)
      response = rest_client.authorise_payment_3dsecure(authorization_3d_request(payment, adyen_3d_params))
      handle_3ds_response(payment, response)
    end

    # Performs and authorization call to Adyen for the payment
    # @raise [Spree::Core::GatewayError] if the encrypted card data is missing
    # @raise [Spree::Core::GatewayError] if the authorize call fails
    def authorise_new_payment payment
      response = perform_authorization(payment)
      handle_adyen_response(payment, response)
    end

    private

    # 3DS responses result in a `failed` ActiveMerchant::Billing::Response, which
    # will cause the payment to be in the `failed` state. To counteract this,
    # we update the column without callbacks when we successfully authorize.
    def handle_3ds_response(payment, response)
      if response.success?
        payment.update_columns(state: 'pending', response_code: response.psp_reference)
        payment.update_adyen_card_data
      else
        raise Authorize3DSecureError
      end
    end

    def perform_authorization(amount, card, gateway_options)
      # If this is a new credit card we should have the encrypted data
      if card.has_payment_profile?
        rest_client.reauthorise_recurring_payment(
          authorization_request(amount, card, gateway_options)
        )
      elsif card.adyen_token
        rest_client.authorise_recurring_payment(
          authorization_request(amount, card, gateway_options).
            merge(encrypted_card_data(card))
        )
      else
        raise MissingTokenError
      end
    end

    def authorization_3d_request payment, redirect_response_params
      order = payment.order
      {
        reference: order.number,
        merchant_account: account_locator.by_order(order),
        amount: {
          value: payment.money.cents,
          currency: payment.currency
        },
        shopper_i_p: order.last_ip_address,
        shopper_email: order.email,
        shopper_reference: order.adyen_shopper_reference,
        billing_address: billing_address_from_source(payment.source),
        md: redirect_response_params["MD"],
        pa_response: redirect_response_params["PaRes"],
        recurring: {
          contract: "RECURRING"
        },
        browser_info: {
          user_agent: payment.request_env["HTTP_USER_AGENT"],
          accept_header: payment.request_env["HTTP_ACCEPT"]
        }
      }
    end

    def authorization_request(amount, card, gateway_options)
      order = Spree::Order.find_by!(number: gateway_options[:order_id].split("-").first)

      {
        reference: order.number,
        merchant_account: account_locator.by_order(order),
        amount: {
          value: amount,
          currency: order.currency
        },
        shopper_i_p: order.last_ip_address,
        shopper_email: order.email,
        shopper_reference: order.adyen_shopper_reference,
        billing_address: billing_address_from_source(card),
        browser_info: {
          user_agent: gateway_options[:HTTP_USER_AGENT],
          accept_header: gateway_options[:HTTP_ACCEPT]
        }
      }
    end

    def encrypted_card_data(source)
      {
        additional_data: {
          card: { encrypted: { json: source.adyen_token } }
        }
      }
    end

    def billing_address_from_source(card)
      address = card.address
      {
        street: address.address1,
        house_number_or_name: "NA",
        city: address.city,
        postal_code: address.zipcode,
        state_or_province: address.state_text || "NA",
        country: address.country.try(:iso),
      }
    end
  end
end
