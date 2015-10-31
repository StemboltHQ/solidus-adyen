require_relative "./communications"

module Spree
  module Adyen
    module Presenters
      # Factory for creating communication presenters, based on a payment
      # source.
      class Communication < SimpleDelegator
        def self.from_source source
          ([source] + source.notifications + source.payment.log_entries).
            sort_by(&:created_at).
            map { |x| build x }
        end

        def self.build object
          case object.class.name
          when "Spree::Adyen::HppSource"
            Communications::HppSource.new(object)

          when "Spree::LogEntry"
            Communications::LogEntry.new(object)

          when "AdyenNotification"
            Spree::Adyen::Presenters::Communications::AdyenNotification.
              new(object)

          else
            fail "Couldn't map to a communication type"

          end
        end
      end
    end
  end
end
