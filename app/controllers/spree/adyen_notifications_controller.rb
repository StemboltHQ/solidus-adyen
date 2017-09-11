module Spree
  class AdyenNotificationsController < AdyenController
    skip_before_action :verify_authenticity_token

    before_action :authenticate

    def notify
      if notification_exists?(params)
        accept
      else
        notification = AdyenNotification.build(params)
        notification.save!

        # Only process the notification if we have an associated order.
        # We might not in the case of test notifications, reports, etc.
        notification.order.try!(:with_lock) do
          Spree::Adyen::NotificationProcessor.new(notification).process!
        end
        accept
      end
    end

    protected
    # Enable HTTP basic authentication
    def authenticate
      authenticate_or_request_with_http_basic do |username, password|
        username == ENV["ADYEN_NOTIFY_USER"] &&
          password == ENV["ADYEN_NOTIFY_PASSWD"]
      end
    end

    private
    def accept
      render plain: "[accepted]"
    end

    def notification_exists? params
      AdyenNotification.exists?(
        psp_reference: params["pspReference"],
        event_code: params["eventCode"]
      )
    end
  end
end
