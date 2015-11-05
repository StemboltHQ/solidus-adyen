module Spree
  module Adyen
    module Presenters
      module Communications
        class AdyenNotification <
          ::Spree::Adyen::Presenters::Communications::Base

          def fields
            { event_code: event_code,
              reason: reason,
              amount: money.format
            }
          end

          def inbound?
            true
          end

          def self.applicable? obj
            obj.is_a? ::AdyenNotification
          end
        end
      end
    end
  end
end
