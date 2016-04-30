module Spree
  module Gateway::AdyenGateway
    extend ActiveSupport::Concern

    included do
      preference :api_password, :string
      preference :api_username, :string
      preference :merchant_account, :string
    end

    def api_password
      ENV["ADYEN_API_PASSWORD"] || preferred_api_password
    end

    def api_username
      ENV["ADYEN_API_USERNAME"] || preferred_api_username
    end

    def merchant_account
      ENV["ADYEN_MERCHANT_ACCOUNT"] || preferred_merchant_account
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

    def capture(amount, psp_reference, currency:, **_opts)
      value = { currency: currency, value: amount }

      handle_response(
        provider.capture_payment(psp_reference, value),
        psp_reference
      )
    end

    def cancel(psp_reference, _gateway_options = {})
      handle_response(
        provider.cancel_or_refund_payment(psp_reference),
        psp_reference
      )
    end

    def credit(amount, psp_reference, currency:, **_opts)
      amount = { currency: currency, value: amount }

      handle_response(
        provider.refund_payment(psp_reference, amount),
        psp_reference
      )
    end

    private

    def message response
      if response.success?
        JSON.pretty_generate(response.params)
      else
        response.fault_message
      end
    end

    def handle_response(response, original_reference = nil)
      ActiveMerchant::Billing::Response.new(
        response.success?,
        message(response),
        response.params,
        authorization: original_reference || response.psp_reference
      )
    end
  end
end
