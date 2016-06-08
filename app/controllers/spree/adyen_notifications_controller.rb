module Spree
  class AdyenNotificationsController < StoreController
    skip_before_filter :verify_authenticity_token

    before_filter :authenticate

    def notify
      notification = AdyenNotification.build(params)

      if notification.order.present?
        process_order_notification!(notification)
      else
        process_notification!(notification)
      end

      accept
    rescue ActiveRecord::RecordNotUnique, ::ArguementError
      # Notification is a duplicate, ignore it and return a success.
      accept
    rescue Spree::OrderMutex::LockFailed
      refuse
    end

    protected
    # Enable HTTP basic authentication
    def authenticate
      authenticate_or_request_with_http_basic do |username, password|
        username == ENV["ADYEN_NOTIFY_USER"] &&
          password == ENV["ADYEN_NOTIFY_PASSWD"]
      end
    end

    def process_order_notification!(notification)
      Spree::OrderMutex.with_lock!(notification.order) do
        process_notification!(notification)
      end
    end

    def process_notification!(notification)
      notification.save!
      Spree::Adyen::NotificationProcessor.new(notification).process!
    end

    private
    def accept
      render text: "[accepted]"
    end

    def refuse
      render text: "[refused]"
    end
  end
end
