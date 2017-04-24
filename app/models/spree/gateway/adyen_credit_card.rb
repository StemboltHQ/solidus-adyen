module Spree
  class Gateway::AdyenCreditCard < Gateway
    class EncryptedDataError < Spree::Core::GatewayError
      def message
        I18n.t(:missing_encrypted_data, scope: 'solidus-adyen')
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
      ActiveMerchant::Billing::Response.new(true, "dummy authorization response")
    end

    def perform_authorization_3d(payment, adyen_3d_params)
      response = rest_client.authorise_payment_3dsecure(authorization_request(payment, false, adyen_3d_params))
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

    def handle_adyen_response(payment, response)
      if response.redirect?
        payment.adyen_api_response = response
        payment.response_code = response.psp_reference
        payment.save!
      elsif response.success?
        payment.response_code = response.psp_reference
        payment.save!
        update_stored_card_data(payment)
      else
        payment.log_entries.create!(details: response.to_yaml)
        raise InvalidDetailsError
      end
    end

    def new_credit_card? source
      source.encrypted_data.present?
    end

    def perform_authorization payment
      # If this is a new credit card we should have the encrypted data
      if new_credit_card?(payment.source)
        rest_client.authorise_recurring_payment(
          authorization_request(payment, true)
        )
      elsif payment.source.has_payment_profile?
        rest_client.reauthorise_recurring_payment(
          authorization_request(payment, false)
        )
      else
        raise EncryptedDataError
      end
    end

    def update_stored_card_data payment
      safe_credit_cards = get_safe_cards(payment.order)
      return nil if safe_credit_cards.nil? || safe_credit_cards.empty?

      # Ensure we use the correct card we just created
      safe_credit_cards.sort_by! { |card| card[:creation_date] }
      safe_credit_card_data = safe_credit_cards.last

      payment.source.update(
        gateway_customer_profile_id: safe_credit_card_data[:recurring_detail_reference],
        cc_type: safe_credit_card_data[:variant],
        last_digits: safe_credit_card_data[:card_number],
        month: "%02d" % safe_credit_card_data[:card_expiry_month],
        year: "%04d" % safe_credit_card_data[:card_expiry_year],
        name: safe_credit_card_data[:card_holder_name]
      )
    end

    def get_safe_cards order
      response = rest_client.list_recurring_details({
        merchant_account: account_locator.by_order(order),
        shopper_reference: reference_number_from_order(order),
      })

      if response.success? && !response.gateway_response.details.blank?
        response.gateway_response.details
      else
        raise ProfileLookupError
      end
    end

    def reference_number_from_order order
      order.user_id.to_s.presence || order.number
    end

    def authorization_3d_request payment, redirect_response_params
      request = {
        reference: payment.order.number,
        merchant_account: merchant_account,
        amount: price_data(payment),
        shopper_i_p: payment.order.last_ip_address,
        shopper_email: payment.order.email,
        shopper_reference: reference_number_from_order(payment.order),
        billing_address: billing_address_from_payment(payment),
        md: redirect_response_params["MD"],
        pa_response: redirect_response_params["PaRes"],
        recurring: {
          contract: "RECURRING"
        }
      }

      request.merge!(browser_info(payment.request_env)) if payment.request_env

      request
    end

    def authorization_request payment, new_card
      request = {
        reference: payment.order.number,
        merchant_account: account_locator.by_order(payment.order),
        amount: price_data(payment),
        shopper_i_p: payment.order.last_ip_address,
        shopper_email: payment.order.email,
        shopper_reference: reference_number_from_order(payment.order),
        billing_address: billing_address_from_payment(payment)
      }
      request.merge!(encrypted_card_data(payment.source)) if new_card
      request.merge!(browser_info(payment.request_env)) if payment.request_env

      request
    end

    def browser_info headers
      {
        browser_info: {
          user_agent: headers["HTTP_USER_AGENT"],
          accept_header: headers["HTTP_ACCEPT"]
        }
      }
    end

    def encrypted_card_data source
      {
        additional_data: {
          card: { encrypted: { json: source.encrypted_data } }
        }
      }
    end

    def billing_address_from_payment payment
      address = payment.source.address
      {
        street: address.address1,
        house_number_or_name: "NA",
        city: address.city,
        postal_code: address.zipcode,
        state_or_province: address.state_text || "NA",
        country: address.country.try(:iso),
      }
    end

    def price_data payment
      {
        value: payment.money.cents,
        currency: payment.currency
      }
    end
  end
end
