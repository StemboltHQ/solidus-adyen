module Spree::Adyen::NotificationProcessing
  AUTO_CAPTURE_ONLY_METHODS = [ "ideal", "c_cash" ].freeze

  AUTHORISATION = "AUTHORISATION".freeze
  CANCELLATION = "CANCELLATION".freeze
  REFUND = "REFUND".freeze
  CANCEL_OR_REFUND = "CANCEL_OR_REFUND".freeze
  CAPTURE = "CAPTURE".freeze
  CAPTURE_FAILED = "CAPTURE_FAILED".freeze
  REFUND_FAILED = "REFUND_FAILED".freeze
  REFUNDED_REVERSED = "REFUNDED_REVERSED".freeze

  def self.find_payment notification
    reference =
      if normal_event? notification
        notification.psp_reference
      else
        notification.original_reference
      end

    Spree::Payment.find_by response_code: reference
  end

  def self.process notification
    payment =
      Spree::Adyen::NotificationProcessing.find_payment(notification)

    # only process the notification if there is a matching payment
    # there's a number of reasons why there may not be a matching payment
    # such as test notifications, reports etc, we just log them and then
    # accept
    if payment
      # if processing fails all modifications should be rolled back and
      # we should not acknowledge the notification.
      Spree::Payment.transaction do
        if !notification.success?
          handle_failure notification, payment

        elsif modification_event? notification
          handle_modification_event notification, payment

        elsif normal_event? notification
          handle_normal_event notification, payment

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

  def self.handle_failure notification, payment
    # ignore failures if the payment was already completed
    return if payment.completed?
    # might have to do something else on modification events,
    # namely refunds
    payment.failure!
  end

  def self.handle_modification_event notification, payment
    case notification.event_code
    when CAPTURE
      complete_payment! notification, payment
    end
  end

  # normal event is defined as just AUTHORISATION
  def self.handle_normal_event notification, payment
    if auto_captured? notification, payment
      complete_payment! notification, payment
    else
      payment.adyen_hpp_capture!
    end
  end

  def self.complete_payment! notification, payment
    money = ::Money.new(notification.value, notification.currency)

    # this is copied from Spree::Payment::Processing#capture
    payment.capture_events.create!(amount: money.to_f)
    payment.update!(amount: payment.captured_amount)
    payment.complete!
  end

  def self.auto_captured? notification, payment
    # todo include bank transfers
    AUTO_CAPTURE_ONLY_METHODS.member?(notification.payment_method) ||
      payment.payment_method.auto_capture? ||
      bank_transfer?(notification)
  end

  # https://docs.adyen.com/display/TD/Notification+fields
  def self.modification_event? notification
    [ CANCELLATION,
      REFUND,
      CANCEL_OR_REFUND,
      CAPTURE,
      CAPTURE_FAILED,
      REFUND_FAILED,
      REFUNDED_REVERSED
    ].member? notification.event_code
  end

  def self.normal_event? notification
    AUTHORISATION == notification.event_code
  end

  def self.bank_transfer? notification
    notification.payment_method.match(/^bankTransfer/)
  end
end
