module Spree
  module Adyen
    module Order
      def adyen_shopper_reference
        user_id.to_s.presence || number
      end

      def requires_manual_refund?
        canceled? && payments.any? do |payment|
          payment.source.try(:requires_manual_refund?)
        end
      end

      private

      def process_payments_with(method)
        if SolidusSupport.solidus_gem_version < Gem::Version.new("1.4.0")
          process_payments_with_v1_4(method)
        else
          super
        end
      end

      # Backport from Solidus 1.4 to address the issue resolved in:
      # https://github.com/solidusio/solidus/pull/1361
      def process_payments_with_v1_4(method)
        # Don't run if there is nothing to pay.
        return true if payment_total >= total

        unprocessed_payments.each do |payment|
          break if payment_total >= total

          payment.public_send(method)

          if payment.completed?
            self.payment_total += payment.amount
          end
        end
      rescue Core::GatewayError => e
        result = !!Spree::Config[:allow_checkout_on_gateway_error]
        errors.add(:base, e.message) && (return result)
      end
    end
  end
end
