module Spree
  module Adyen
    module Order
      def requires_manual_refund?
        canceled? && payments.any? do |payment|
          payment.source.try(:requires_manual_refund?)
        end
      end
    end
  end
end
