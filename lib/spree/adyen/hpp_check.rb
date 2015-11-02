# Used when we have to override functionally inside spree, usually payments,
# that is a conditional flow only on hpp payments.
module Spree::Adyen::HppCheck
  def hpp_payment? payment = self
    payment.source.class == Spree::Adyen::HppSource
  end
end
