module Spree
  class CreditCard
    module AdyenToken
      private

      def require_card_numbers?
        super && !adyen_token.present?
      end
    end
  end
end
