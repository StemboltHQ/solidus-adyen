module Spree
  module Adyen
    # Class responsible for taking in a notification from Adyen and applying
    # some form of modification to the associated payment.
    #
    # I would in the future like to refactor this by breaking this into
    # separate classes that are only aware of how to process specific kinds of
    # notifications (auth, capture, refund, etc.).
    class NotificationProcessor
      attr_accessor :notification, :payment

      def initialize(notification, payment = nil)
        self.notification = notification
        self.payment = payment ? payment : notification.payment
      end

      # for the given payment, process all notifications that are currently
      # unprocessed in the order that they were dispatched.
      def self.process_outstanding!(payment)
        Spree::Payment.transaction do
          payment.
            source.
            notifications(true). # bypass caching
            unprocessed.
            as_dispatched.
            map do |notification|
              new(notification, payment).process!
            end
        end
      end

      # only process the notification if there is a matching payment there's a
      # number of reasons why there may not be a matching payment such as test
      # notifications, reports etc, we just log them and then accept
      def process!
        Spree::Payment.transaction do
          if payment
            if !notification.success?
              handle_failure

            elsif notification.modification_event?
              handle_modification_event

            elsif notification.normal_event?
              handle_normal_event

            end
          end
        end

        return notification
      end

      private

      def handle_failure
        notification.processed!
        # ignore failures if the payment was already completed
        return if payment.completed?
        # might have to do something else on modification events,
        # namely refunds
        payment.failure!
      end

      def handle_modification_event
        if notification.capture?
          notification.processed!
          complete_payment!

        elsif notification.cancel_or_refund?
          notification.processed!
          payment.void

        elsif notification.refund?
          payment.refunds.create!(
            amount: notification.value / 100, # cents to dollars
            transaction_id: notification.psp_reference,
            refund_reason_id: ::Spree::RefundReason.first.id # FIXME
          )
          # payment was processing, move back to completed
          payment.complete! unless payment.completed?
          notification.processed!
        end
      end

      # normal event is defined as just AUTHORISATION
      def handle_normal_event
        if notification.auto_captured?
          complete_payment!

        else
          payment.capture!

        end
        notification.processed!
      end

      def complete_payment!
        money = ::Money.new(notification.value, notification.currency)

        # this is copied from Spree::Payment::Processing#capture
        payment.capture_events.create!(amount: money.to_f)
        payment.update!(amount: payment.captured_amount)
        payment.complete!
      end
    end
  end
end
