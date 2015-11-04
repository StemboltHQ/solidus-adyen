module Spree
  module Adyen
    # Used when we have to override functionally inside spree, usually payments,
    # that is a conditional flow only on hpp payments.
    module HppCheck
      def hpp_payment? payment = self
        payment.source.class == Spree::Adyen::HppSource
      end
    end
  end
end
