module Spree
  class AdyenNotificationsController < AdyenController
    skip_before_action :verify_authenticity_token

    before_action :authenticate

    # Avoid collisions with the user being sent to AdyenRedirectController
    class_attribute :processing_delay
    self.processing_delay = 10.seconds

    def notify
      notification = AdyenNotification.build(params)
      begin
        notification.save!
      rescue ActiveRecord::RecordNotUnique
        # Notification is a duplicate, ignore it.
      else
        enqueue_job(notification)
      end
      accept
    end

    private

    # Enable HTTP basic authentication
    def authenticate
      authenticate_or_request_with_http_basic do |username, password|
        username == ENV["ADYEN_NOTIFY_USER"] &&
          password == ENV["ADYEN_NOTIFY_PASSWD"]
      end
    end

    def accept
      render plain: "[accepted]"
    end

    def enqueue_job(notification)
      Spree::Adyen::NotificationJob.set(
        wait: processing_delay
      ).perform_later(notification)
    end
  end
end
