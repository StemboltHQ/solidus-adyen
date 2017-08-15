module Spree
  module Adyen
    module CheckoutController
      def self.included(mod)
        mod.before_action :set_payment_request_env, only: :update
      end

      def set_payment_request_env
        @order.payments.each { |payment| payment.request_env = request.headers.env }
      end
    end
  end
end
