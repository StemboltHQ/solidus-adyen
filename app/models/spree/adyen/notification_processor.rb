class Spree::Adyen::NotificationProcessor
  attr_accessor :notification, :payment

  def initialize(notification)
    self.notification = notification
    self.payment = self.notification.payment
  end

  def process!
    # only process the notification if there is a matching payment
    # there's a number of reasons why there may not be a matching payment
    # such as test notifications, reports etc, we just log them and then
    # accept
    if payment
      # if processing fails all modifications should be rolled back and
      # we should not acknowledge the notification.
      Spree::Payment.transaction do
        if !notification.success?
          handle_failure

        elsif notification.modification_event?
          handle_modification_event

        elsif notification.normal_event?
          handle_normal_event

        else
          # the notification was not handled by any clause and should be logged
          # as unprocessed, this is typical of any event like a dispute or any
          # other currently unsupported event. This could potentially let us go
          # back and correct them retroactively or see what was actually handled
          # by the system.
          notification.processed = false
          return notification
        end
      end

      notification.processed = true
    end

    notification.save!
    return notification
  end

  private

  def handle_failure
    # ignore failures if the payment was already completed
    return if payment.completed?
    # might have to do something else on modification events,
    # namely refunds
    payment.failure!
  end

  def handle_modification_event
    if notification.capture?
      complete_payment!
    end
  end

  # normal event is defined as just AUTHORISATION
  def handle_normal_event
    if notification.auto_captured?
      complete_payment!
    else
      payment.adyen_hpp_capture!
    end
  end

  def complete_payment!
    money = ::Money.new(notification.value, notification.currency)

    # this is copied from Spree::Payment::Processing#capture
    payment.capture_events.create!(amount: money.to_f)
    payment.update!(amount: payment.captured_amount)
    payment.complete!
  end
end
