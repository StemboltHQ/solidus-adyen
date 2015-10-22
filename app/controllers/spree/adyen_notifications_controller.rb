class Spree::AdyenNotificationsController < Spree::StoreController
  skip_before_filter :verify_authenticity_token

  before_filter :authenticate

  def notify
    notification = AdyenNotification.build(params)

    if duplicate? notification
      accept and return
    end

    # if a failure occurs we don't want to send anything, it wil be
    # interpretted as a success.
    AdyenNotification.transaction do
      payment =
        Spree::Adyen::NotificationProcessing.find_payment(notification)

      # only process the notification if there is a matching payment
      # there's a number of reasons why there may not be a matching payment
      # such as test notifications, reports etc, we just log them and then
      # accept
      if payment
        Spree::Adyen::NotificationProcessing.process notification, payment
      end

      notification.save!
    end

    # accept after processing has completed
    accept
  end

  protected
  # Enable HTTP basic authentication
  def authenticate
    authenticate_or_request_with_http_basic do |username, password|
      username == ENV['ADYEN_NOTIFY_USER'] && password == ENV['ADYEN_NOTIFY_PASSWD']
    end
  end

  private
  def accept
    render text: "[accepted]"
  end

  def duplicate? notification
    AdyenNotification.exists?(
      psp_reference: notification.psp_reference,
      event_code: notification.event_code,
      success: notification.success
    )
  end
end
