module Spree
  module Adyen
    module Order
      def adyen_shopper_reference
        user_id.to_s.presence || number
      end

      def requires_manual_refund?
        canceled? && payments.any? do |payment|
          payment.source.try(:requires_manual_refund?)
        end
      end
    end
  end
end
