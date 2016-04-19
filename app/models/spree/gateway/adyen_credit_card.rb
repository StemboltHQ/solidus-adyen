module Spree
  class Gateway::AdyenCreditCard < Gateway
    def provider_class
      ::Adyen::API
    end
  end
end
