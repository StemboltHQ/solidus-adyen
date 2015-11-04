module Spree::Adyen::Presenters::Communications
  class LogEntry < Base
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
