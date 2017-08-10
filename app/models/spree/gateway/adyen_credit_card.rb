module Spree
  class Gateway::AdyenCreditCard < Gateway
    class MissingTokenError < Spree::Core::GatewayError
      def message
        I18n.t(:missing_token_error, scope: 'solidus-adyen')
      end
    end

    class ProfileLookupError < Spree::Core::GatewayError
      def message
        I18n.t(:profile_lookup_failed, scope: 'solidus-adyen')
      end
    end

    class InvalidDetailsError < Spree::Core::GatewayError
      def message
        I18n.t(:credit_card_data_refused, scope: 'solidus-adyen')
      end
    end

    include Spree::Gateway::AdyenGateway
    preference :cse_library_location, :string

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

    def authorise_3d_secure_payment(payment, adyen_3d_params)
      request.merge!(browser_info(payment.request_env)) if payment.request_env
      response = rest_client.authorise_payment_3dsecure(authorization_3d_request(payment, adyen_3d_params))
      handle_adyen_response(payment, response)
    end

    # Performs and authorization call to Adyen for the payment
    # @raise [Spree::Core::GatewayError] if the encrypted card data is missing
    # @raise [Spree::Core::GatewayError] if the authorize call fails
    def authorise_new_payment payment
      response = perform_authorization(payment)
      handle_adyen_response(payment, response)
    end

    private

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
      request = {
        reference: payment.order.number,
        merchant_account: account_locator.by_order(payment.order),
        amount: {
          value: payment.money.cents,
          currency: payment.currency
        },
        shopper_i_p: payment.order.last_ip_address,
        shopper_email: payment.order.email,
        shopper_reference: order.adyen_shopper_reference,
        billing_address: billing_address_from_source(payment.source),
        md: redirect_response_params["MD"],
        pa_response: redirect_response_params["PaRes"],
        recurring: {
          contract: "RECURRING"
        }
      }

      request.merge!(browser_info(payment.request_env)) if payment.request_env

      request
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
        billing_address: billing_address_from_source(card)
      }
    end

    def browser_info headers
      {
        browser_info: {
          user_agent: headers["HTTP_USER_AGENT"],
          accept_header: headers["HTTP_ACCEPT"]
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
