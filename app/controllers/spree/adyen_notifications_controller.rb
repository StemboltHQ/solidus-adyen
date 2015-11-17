module Spree
  class AdyenNotificationsController < StoreController
    skip_before_filter :verify_authenticity_token

    before_filter :authenticate

    def notify
      notification = AdyenNotification.build(params)

      if notification.duplicate?
        accept and return
      end

      notification.save!

      # prevent alteration to associated payment while we're handling the action
      Spree::Adyen::NotificationProcessor.new(notification).process!
      accept
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
  end
end
