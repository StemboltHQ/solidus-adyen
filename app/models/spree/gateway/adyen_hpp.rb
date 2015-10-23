module Spree
  # Gateway for Adyen Hosted Payment Pages solution
  class Gateway::AdyenHPP < Gateway
    preference :skin_code, :string
    preference :shared_secret, :string
    preference :days_to_ship, :integer, default: 1
    preference :api_username, :string
    preference :api_password, :string
    preference :merchant_account, :string

    def merchant_account
      ENV['ADYEN_MERCHANT_ACCOUNT'] || preferred_merchant_account
    end

    def provider_class
      ::Adyen::API
    end

    def provider
      ::Adyen.configuration.api_username =
        (ENV['ADYEN_API_USERNAME'] || preferred_api_username)
      ::Adyen.configuration.api_password =
        (ENV['ADYEN_API_PASSWORD'] || preferred_api_password)
      ::Adyen.configuration.default_api_params[:merchant_account] =
        merchant_account

      provider_class
    end

    def method_type
      "adyen"
    end

    def shared_secret
      ENV['ADYEN_SHARED_SECRET'] || preferred_shared_secret
    end

    def skin_code
      ENV['ADYEN_SKIN_CODE'] || preferred_skin_code
    end

    def ship_before_date
      preferred_days_to_ship.days.from_now
    end

    def authorize(amount, source, gateway_options)
      # to get around the order checking for processed payments we create payments
      # in the checkout state and allow the payment method to attempt to auth
      # them here. We just return a dummy response here because the payment has
      # already been authorized
      ActiveMerchant::Billing::Response.new(true, 'successful hpp payment')
    end

    def capture(amount, source, currency:, **_opts)
      value = { currency: currency, value: amount }

      response = provider.capture_payment(source.psp_reference, value)

      ActiveMerchant::Billing::Response.new(
        response.success?,
        JSON.pretty_generate(response.params),
        {},
        authorization: source.psp_reference)
    end

    # According to Spree Processing class API the response object should respond
    # to an authorization method which return value should be assigned to payment
    # response_code
    def void(response_code, gateway_options = {})
      response = provider.cancel_payment(response_code)

      if response.success?
        def response.authorization; psp_reference; end
      else
        # TODO confirm the error response will always have these two methods
        def response.to_s
          "#{result_code} - #{refusal_reason}"
        end
      end
      response
    end

    def credit(credit_cents, transaction_id, gateway_options = {})
      currency = gateway_options[:currency]
      currency ||= gateway_options[:originator].payment.currency
      amount = { currency: currency, value: credit_cents }
      response = provider.refund_payment transaction_id, amount

      if response.success?
        def response.authorization; psp_reference; end
      else
        def response.to_s
          refusal_reason
        end
      end

      response
    end
  end
end
