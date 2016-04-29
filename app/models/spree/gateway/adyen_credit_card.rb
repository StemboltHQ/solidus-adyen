module Spree
  class Gateway::AdyenCreditCard < Gateway
    preference :api_password, :string
    preference :api_username, :string
    preference :cse_token, :string
    preference :merchant_account, :string

    def api_password
      ENV["ADYEN_API_PASSWORD"] || preferred_api_password
    end

    def api_username
      ENV["ADYEN_API_USERNAME"] || preferred_api_username
    end

    def cse_token
      ENV["ADYEN_CSE_TOKEN"] || preferred_cse_token
    end

    def merchant_account
      ENV["ADYEN_MERCHANT_ACCOUNT"] || preferred_merchant_account
    end

    def method_type
      "adyen_encrypted_cc"
    end

    def provider_class
      ::Adyen::API
    end

    def provider
      ::Adyen.configuration.api_username = api_username
      ::Adyen.configuration.api_password = api_password
      ::Adyen.configuration.default_api_params[:merchant_account] = merchant_account

      provider_class
    end

    # We need to use recurring payments so that Solidus can store card tokens and
    # disassociate creating the card from running the payment.
    # @see #create_profile
    def payment_profiles_supported?
      true
    end

    def authorize(amount, card, gateway_options)
      response = provider.authorise_recurring_payment(
        gateway_options[:order_id],
        amount_from_gateway_options(amount, gateway_options),
        shopper_data_from_gateway_options(gateway_options),
        card.gateway_customer_profile_id
      )
      active_merchant_response = ActiveMerchant::Billing::Response.new(
        response.success?,
        response.result_code,
        response.params,
        {
          authorization: response.psp_reference,
          error_code: response.refusal_reason
        }
      )
    end

    def create_profile(payment)
      # We only need to do this once.
      return if payment.source.has_payment_profile?

      # Run a request for no money just to store the card data.
      # It has to be recurring (args[4] == true).
      response = provider.authorise_payment(
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
          name: safe_credit_card_data[:card][:name]
        )
      end
    end

    private

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
