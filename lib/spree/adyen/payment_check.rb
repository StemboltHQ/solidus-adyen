module Spree
  module Adyen
    # Used when we have to override functionally inside spree, usually payments,
    # that is a conditional flow only on adyen payments.
    module PaymentCheck
      def hpp_payment? payment = self
        payment.source.class == Spree::Adyen::HppSource
      end

      # Always return false for now until credit card payments are updated to
      # behave correctly. They are currently not associated with notifications
      # properly, so they will not be transitioned out of `processing`.
      def adyen_cc_payment? payment = self
        # payment.payment_method.class == Spree::Gateway::AdyenCreditCard
        false
      end
    end
  end
end
