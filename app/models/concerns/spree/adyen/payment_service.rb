module Spree
  module Adyen
    module PaymentService
      extend ActiveSupport::Concern

      BILLING_ADDRESS_PARTIAL = <<-EOXML
            <payment:billingAddress>
              <common:street>%s</common:street>
              <common:houseNumberOrName>%s</common:houseNumberOrName>
              <common:city>%s</common:city>
              <common:stateOrProvince>%s</common:stateOrProvince>
              <common:postalCode>%s</common:postalCode>
              <common:country>%s</common:country>
            </payment:billingAddress>
      EOXML

      included do
        private

        def payment_request_body(content)
          validate_parameters!(:merchant_account, :reference, :amount => [:currency, :value])
          content << amount_partial
          content << installments_partial if @params[:installments]
          content << shopper_partial if @params[:shopper]
          content << billing_address_partial if @params[:billing_address]
          content << fraud_offset_partial if @params[:fraud_offset]
          content << capture_delay_partial if @params[:instant_capture]
          ::Adyen::API::PaymentService::LAYOUT %
            [@params[:merchant_account], @params[:reference], content]
        end

        def billing_address_partial
          billing_address_params = [
            :street,
            :house_number_or_name,
            :city,
            :postal_code,
            :state_or_province,
            :country
          ]

          validate_parameters!(billing_address: billing_address_params)
          ::Adyen::API::PaymentService::BILLING_ADDRESS_PARTIAL %
            @params[:billing_address].values_at(*billing_address_params)
        end
      end
    end
  end
end
