module Spree
  module Adyen
    class BillingResponse < ActiveMerchant::Billing::Response
      REDIRECT_SHOPPER = "RedirectShopper"

      def issuer_url
        @params["paymentResult.issuerUrl"]
      end

      def md
        @params["paymentResult.md"]
      end

      def pa_request
        @params["paymentResult.paRequest"]
      end

      def psp_reference
        @params["paymentResult.pspReference"]
      end

      def result_code
        @params["paymentResult.resultCode"]
      end

      def redirect?
        result_code == REDIRECT_SHOPPER
      end
    end
  end
end
