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
      ::Adyen::REST
    end

    def capture(amount, psp_reference, currency:, **_opts)
      params = payment_params(amount, currency, psp_reference)

      handle_response(rest_client.capture_payment(params), psp_reference)
    end

    def cancel(psp_reference, _gateway_options = {})
      params = {
        merchant_account: merchant_account,
        original_reference: psp_reference
      }

      handle_response(rest_client.cancel_payment(params), psp_reference)
    end


    def credit(amount, source = nil, psp_reference, currency: nil, **options)
      # in the case of a "refund", we don't have the full gateway_options
      currency ||= options[:originator].payment.currency
      params = payment_params(amount, currency, psp_reference)
      params.merge!(options.slice(:additional_data)) if options[:additional_data]

      handle_response(rest_client.refund_payment(params), psp_reference)
    end

    private

    def rest_client
      @client ||= Adyen::Client.new(self)
    end

    def message response
      if response.success?
        JSON.pretty_generate(response.attributes)
      else
        response[:refusal_reason]
      end
    end

    def handle_response(response, original_reference = nil)
      ActiveMerchant::Billing::Response.new(
        response.success?,
        message(response),
        response.attributes,
        authorization: original_reference || response.psp_reference
      )
    end

    def payment_params(amount, currency, psp_reference)
      {
        merchant_account: merchant_account,
        modification_amount: { currency: currency, value: amount },
        original_reference: psp_reference,
      }
    end
  end
end
