module Spree
  module Adyen
    module REST
      module AuthorisePaymentResponse
        def success?
          super && authorised?
        end
      end
    end
  end
end
