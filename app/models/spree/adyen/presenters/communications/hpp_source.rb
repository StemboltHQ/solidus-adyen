module Spree::Adyen::Presenters::Communications
  class HppSource < Base
    def fields
      { result: auth_result,
        payment_method: payment_method
      }
    end

    def success?
      true
    end

    def processed?
      true
    end

    def inbound?
      true
    end
  end
end
