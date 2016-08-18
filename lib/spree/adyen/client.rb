module Spree
  module Adyen
    class Client
      def initialize payment_method
        @payment_method = payment_method
      end

      def authorise_recurring_payment params
        execute_request(:authorise_recurring_payment, params)
      end

      def reauthorise_recurring_payment params
        execute_request(:reauthorise_recurring_payment, params)
      end

      def capture_payment params
        execute_request(:capture_payment, params)
      end

      def refund_payment params
        execute_request(:refund_payment, params)
      end

      def cancel_payment params
        execute_request(:cancel_or_refund_payment, params)
      end

      def list_recurring_details params
        execute_request(:list_recurring_details, params)
      end

      private

      def client
        @client ||= ::Adyen::REST::Client.new(
          ::Adyen.configuration.environment,
          @payment_method.api_username,
          @payment_method.api_password
        )
      end

      def execute_request method, params
        ::Adyen::REST.session(client) do |client|
          client.public_send(method, params)
        end
      rescue ::Adyen::REST::ResponseError => error
        raise Spree::Core::GatewayError.new(error.message)
      end
    end
  end
end
