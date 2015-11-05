module Spree
  module Adyen
    module Presenters
      module Communications
        # Base presenters for generic server-api communication representation
        #
        # All communication presenters are expected to implement
        # fields
        # success?
        # processed?
        # inbound?
        class Base < SimpleDelegator
          # force to_partial_path to be called on the delegator and not the
          # delgatee
          def to_model
            self
          end

          def to_partial_path
            "spree/adyen/communication/communication"
          end

          def created_at_s
            created_at.strftime "%d %b %H:%M:%S.%4N"
          end

          def present_fields
            fields.compact
          end

          def css_class
            [
              success? ? "success" : "failure",
              processed? ? "processed" : "unprocessed",
              inbound? ? "received" : "sent"
            ].
            map { |klass| css_prefix klass }.
            join(" ")
          end

          private

          def css_prefix klass
            "adyen-comm-" + klass
          end
        end
      end
    end
  end
end
