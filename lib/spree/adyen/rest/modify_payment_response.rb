module Spree
  module Adyen
    module REST
      module ModifyPaymentResponse
        def success?
          super && received?
        end
      end
    end
  end
end
