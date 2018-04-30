module Spree
  class Gateway::AdyenRatepay < Spree::PaymentMethod
    class InvoiceRejectedError < Spree::Core::GatewayError; end

    class MissingDateOfBirthError < Spree::Core::GatewayError
      def message
        I18n.t(:missing_date_of_birth, scope: "solidus-adyen")
      end
    end

    include Spree::Gateway::AdyenGateway

    preference :device_sid, :string

    def device_sid
      ENV["RATEPAY_DEVICE_SID"] || preferred_device_sid
    end

    def partial_name
      "adyen_ratepay"
    end

    def payment_source_class
      Adyen::RatepaySource
    end

    def authorize(amount, source, gateway_options)
      # We need to authorise Ratepay payments on the `payment` checkout step,
      # so that we don't need to persist the user's date of birth. Once we hit
      # this the payment should already be authorized.
      ActiveMerchant::Billing::Response.new(true, "successful Ratepay authorization")
    end

    def authorise_new_payment(payment)
      raise MissingDateOfBirthError unless payment.source.has_dob?

      response = perform_authorisation(payment)
      if response.success?
        payment.source.update!(
          auth_result: response.gateway_response.result_code,
          psp_reference: response.psp_reference,
          merchant_reference: payment.order.number
        )
        payment.update!(response_code: response.psp_reference)
      else
        payment.log_entries.create!(details: response.to_yaml)
        raise InvoiceRejectedError, response.message
      end
    end

    private

    def perform_authorisation payment
      params = Spree::Adyen::HPP.
        configuration.
        params_class.new(payment.order, self).
        authorise_invoice(payment.source.date_of_birth).
        merge({
          device_fingerprint: payment.source.device_token,
          selected_brand: "ratepay_#{payment.order.bill_address.country.iso}"
        })

      Spree::Adyen::Client.new(self).authorise_payment(params)
    end
  end
end
