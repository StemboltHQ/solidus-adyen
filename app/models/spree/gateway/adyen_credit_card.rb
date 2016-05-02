module Spree
  class Gateway::AdyenCreditCard < Gateway
    class ClearTextCardNumberError < StandardError; end

    include Spree::Gateway::AdyenGateway
    preference :cse_library_location, :string

    def cse_library_location
      ENV["ADYEN_CSE_LIBRARY_LOCATION"] || preferred_cse_library_location
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
      response = provider.authorise_payment(
        reference_number_from_order(payment.order),
        zero_amount(payment.order),
        shopper_data_from_order(payment.order),
        encrypted_card_data(payment.source),
        true
      )
      raise Spree::Core::GatewayError.new(I18n.t(:credit_card_data_refused, scope: 'solidus-adyen')) unless response.success?
      # Because the above call does not return the recurring detail reference,
      # ask Adyen for it.
      safe_credit_cards = get_safe_cards(payment.order)
      # Adyen returns nil if there's no safe cards, rather than an empty Array.
      safe_credit_card_data = safe_credit_cards.try!(:last)
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

    def reference_number_from_order(order)
      order.user_id || order.number
    end

    def reference_number_from_gateway_options(gateway_options)
      gateway_options[:customer_id] || gateway_options[:order_id].split("-").first
    end

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
        reference: reference_number_from_gateway_options(gateway_options),
        email: gateway_options[:email],
        ip: gateway_options[:ip],
        statement: gateway_options[:order_id]
      }
    end

    def get_safe_cards(order)
      provider.list_recurring_details(
        reference_number_from_order(order)
      ).details
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
        reference: reference_number_from_order(order),
        email: order.email,
        ip: order.last_ip_address,
        statement: order.number
      }
    end
  end
end
