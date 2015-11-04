module Spree
  module Adyen
    module Presenters
      module Communications
        class LogEntry < ::Spree::Adyen::Presenters::Communications::Base
          delegate :success?, :message, to: :parsed_details

          def processed?
            true
          end

          def inbound?
            false
          end

          def fields
            { message: message
            }
          end
        end
      end
    end
  end
end
