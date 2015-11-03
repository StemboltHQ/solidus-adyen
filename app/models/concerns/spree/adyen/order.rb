module Spree::Adyen::Order
  def requires_manual_refund?
    canceled? && payments.any? do |payment|
      payment.source.try(:requires_manual_refund?)
    end
  end
end
