module Spree::Adyen::Presenters::Communications
  class AdyenNotification < Base
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
