module Spree
  module Adyen
    class ApiResponse
      attr_reader :gateway_response

      def initialize gateway_response
        @gateway_response = gateway_response
      end

      def success?
        !error_response? && gateway_response.success?
      end

      def redirect?
        @gateway_response.is_a?(::Adyen::REST::AuthorisePayment::Response) &&
          @gateway_response.attributes["paymentResult.resultCode"] == "RedirectShopper"
      end

      def psp_reference
        return nil if error_response?
        @gateway_response[:psp_reference]
      end

      def attributes
        if error_response?
          {}
        else
          @gateway_response.attributes
        end
      end

      def message
        if success?
          JSON.pretty_generate(@gateway_response.attributes)
        else
          error_message
        end
      end

      private

      def authorisation_response?
        @gateway_response.is_a?(::Adyen::REST::AuthorisePayment::Response)
      end

      def modification_response?
        @gateway_response.is_a?(::Adyen::REST::ModifyPayment::Response)
      end

      def error_response?
        @gateway_response.is_a?(::Adyen::REST::ResponseError)
      end

      def error_message
        if authorisation_response?
          @gateway_response[:refusal_reason]
        elsif modification_response?
          @gateway_response[:response]
        elsif error_response?
          @gateway_response.message
        else
          I18n.t(:unknown_gateway_error, scope: "solidus-adyen")
        end
      end
    end
  end
end
