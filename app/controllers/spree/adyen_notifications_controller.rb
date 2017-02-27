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

        # prevent alteration to associated payment while we're handling the action
        Spree::Adyen::NotificationProcessor.new(notification).process!
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
      render text: "[accepted]"
    end

    def notification_exists? params
      AdyenNotification.exists?(
        psp_reference: params["pspReference"],
        event_code: params["eventCode"]
      )
    end
  end
end
