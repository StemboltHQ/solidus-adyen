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
        end
      end
    end
  end
end
