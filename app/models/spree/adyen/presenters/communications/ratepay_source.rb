module Spree
  module Adyen
    module Presenters
      module Communications
        class RatepaySource < ::Spree::Adyen::Presenters::Communications::Base
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

          def self.applicable? obj
            obj.is_a? Spree::Adyen::RatepaySource
          end
        end
      end
    end
  end
end
