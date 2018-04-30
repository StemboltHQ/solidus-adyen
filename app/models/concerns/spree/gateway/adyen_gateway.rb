module Spree
  module Gateway::AdyenGateway
    extend ActiveSupport::Concern

    included do
      preference :api_password, :string
      preference :api_username, :string
      preference :merchant_account, :string
      preference :store_merchant_account_map, :hash, default: {}
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

    def account_locator
      SolidusAdyen::AccountLocator.new(
        preferred_store_merchant_account_map,
        merchant_account
      )
    end

    def gateway_class
      ::Adyen::REST
    end

    def capture(amount, psp_reference, currency:, **_opts)
      params = modification_request(amount, currency, psp_reference)

      handle_response(rest_client.capture_payment(params), psp_reference)
    end

    def cancel(psp_reference, _gateway_options = {})
      params = {
        merchant_account: account_locator.by_reference(psp_reference),
        original_reference: psp_reference
      }

      handle_response(rest_client.cancel_payment(params), psp_reference)
    end


    def credit(amount, source = nil, psp_reference, currency: nil, **options)
      # in the case of a "refund", we don't have the full gateway_options
      currency ||= options[:originator].payment.currency
      params = modification_request(amount, currency, psp_reference)
      params.merge!(options.slice(:additional_data)) if options[:additional_data]

      handle_response(rest_client.refund_payment(params), psp_reference)
    end

    def rest_client
      @client ||= Adyen::Client.new(self)
    end

    private

    def handle_response(response, original_reference = nil)
      Spree::Adyen::BillingResponse.new(
        response.success?,
        response.message,
        response.attributes,
        authorization: original_reference || response.psp_reference
      )
    end

    def modification_request(amount, currency, psp_reference)
      {
        merchant_account: account_locator.by_reference(psp_reference),
        modification_amount: { currency: currency, value: amount },
        original_reference: psp_reference,
      }
    end
  end
end
