module Spree
  class Gateway::AdyenCreditCard < Gateway
    class ClearTextCardNumberError < StandardError; end

    include Spree::Gateway::AdyenGateway
    preference :cse_library_location, :string

    def cse_library_location
      ENV["ADYEN_CSE_LIBRARY_LOCATION"] || preferred_cse_library_location.presence || "test-adyen-encrypt.js"
    end

    def method_type
      "adyen_encrypted_cc"
    end

    # We need to use recurring payments so that Solidus can store card tokens and
    # disassociate creating the card from running the payment.
    # @see #create_profile
    def payment_profiles_supported?
      true
    end

    # Run a fake authorization request to store the card data with Adyen, then retrieve
    # the brand new customer profile ID from them. Does nothing if the card already has
    # a customer profile ID.
    def create_profile(payment)
      # We only need to do this once.
      return if payment.source.has_payment_profile?
      raise ClearTextCardNumberError if payment.source.number.present?
      # Run a request for no money just to store the card data.
      # It has to be recurring (args[4] == true).
      provider.authorise_payment(
        payment.order.number,
        zero_amount(payment.order),
        shopper_data_from_order(payment.order),
        encrypted_card_data(payment.source),
        true
      )
      # Because the above call does not return the recurring detail reference,
      # ask Adyen for it.
      safe_credit_card_data = get_last_credit_card_for_adyen_user(payment)
      if safe_credit_card_data
        payment.source.update(
          gateway_customer_profile_id: safe_credit_card_data[:recurring_detail_reference],
          cc_type: safe_credit_card_data[:variant],
          last_digits: safe_credit_card_data[:card][:number],
          month: "%02d" % safe_credit_card_data[:card][:expiry_date].month,
          year: "%04d" % safe_credit_card_data[:card][:expiry_date].year.to_s,
          name: safe_credit_card_data[:card][:holder_name]
        )
      end
    end

    def authorize(amount, card, gateway_options)
      response = authorize_payment(amount, card, gateway_options, false)
      handle_response(response)
    end

    def purchase(amount, card, gateway_options)
      response = authorize_payment(amount, card, gateway_options, true)
      handle_response(response)
    end

    private

    def authorize_payment(amount, card, gateway_options, instant_capture = false)
      provider.authorise_recurring_payment(
        gateway_options[:order_id],
        amount_from_gateway_options(amount, gateway_options),
        shopper_data_from_gateway_options(gateway_options),
        card.gateway_customer_profile_id,
        nil,
        instant_capture
      )
    end

    def shopper_data_from_gateway_options(gateway_options)
      {
        reference: gateway_options[:customer_id],
        email: gateway_options[:email],
        ip: gateway_options[:ip],
        statement: gateway_options[:order_id]
      }
    end

    def get_last_credit_card_for_adyen_user(payment)
      provider.list_recurring_details(payment.order.user_id).details.last
    end

    def zero_amount(order)
      {
        value: 0,
        currency: order.currency
      }
    end

    def amount_from_gateway_options(amount, gateway_options)
      {
        value: amount,
        currency: gateway_options[:currency]
      }
    end

    def encrypted_card_data(card)
      {
        encrypted: {
          json: card.encrypted_data
        }
      }
    end

    def shopper_data_from_order(order)
      {
        reference: order.user_id,
        email: order.email,
        ip: order.last_ip_address,
        statement: order.number
      }
    end
  end
end
