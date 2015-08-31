module Spree
  class AdyenNotificationsController < StoreController
    skip_before_filter :verify_authenticity_token

    before_filter :authenticate

    def notify
      @notification = AdyenNotification.log(params)
      @notification.handle!
      if @notification.event_code == "REFUND"
        #this exists purely to log the transaction ID of the refund. It might make sense to
        #refactor this so that it lives elswhere.
        @payment = Spree::Payment.find_by(response_code: @notification.original_reference)
        @refund = Spree::Refund.where(payment_id: @payment.id).last
        @refund.transaction_id = @notification.psp_reference
        @refund.save
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      # Validation failed, because of the duplicate check.
      # So ignore this notification, it is already stored and handled.
    ensure
      # Always return that we have accepted the notification
      render :text => '[accepted]'
    end

    protected
      # Enable HTTP basic authentication
      def authenticate
        authenticate_or_request_with_http_basic do |username, password|
          username == ENV['ADYEN_NOTIFY_USER'] && password == ENV['ADYEN_NOTIFY_PASSWD']
        end
      end
  end
end
