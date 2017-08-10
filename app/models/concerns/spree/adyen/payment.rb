# Because adyen payment modifications are delayed we don't actually know if
# the request succeeded after doing it. For that reason we can't use the
# standard capture! and friends as they change the payment state and would
# result is false positives (payment could fail after capture).
module Spree
  module Adyen
    module Payment
      extend ActiveSupport::Concern
      include Spree::Adyen::PaymentCheck

      included do
        after_create :authorise_on_create, if: :should_authorise?

        attr_accessor :adyen_api_response

        private

        def authorise_on_create
          payment_method.authorise_new_payment(self)
        end
      end

      def authorize!
        super
        update_adyen_card_data if adyen_cc_payment?
      end

      # Spree::Payment#process will call purchase! for payment methods with
      # auto_capture enabled. Since we authorize credit cards in the payment
      # step already, we just need to capture the payment here.
      def purchase!
        if ratepay?
          capture!
        elsif adyen_cc_payment?
          authorize!
          capture!
        else
          super
        end
      end

      # capture! :: bool | error
      def capture!
        if hpp_payment? || adyen_cc_payment? || ratepay?
          amount = money.money.cents
          process do
            payment_method.send(
              :capture, amount, response_code, gateway_options)
          end
        else
          super
        end
      end

      # credit! :: bool | error
      #
      # Issue a request to credit the payment, this does NOT perform validation
      # on the amount to be credited, which is assumed to have been done prior
      # to this.
      #
      # credit! is only implemented for hpp payments, because of the delayed
      # manner of Adyen api communications. If this method is called on a
      # payment that is not from Adyen then it should fail. This is crummy way
      # of getting around the fact that Payment methods cannot specifiy these
      # methods.
      def credit! amount, options
        if hpp_payment? || adyen_cc_payment?
          process { payment_method.credit(amount, response_code, options) }
        else
          fail NotImplementedError, "Spree::Payment does not implement credit!"
        end
      end

      # cancel! :: bool | error
      #
      # Borrowed from handle_void_response, this has been modified so that it
      # won't actually void the payment _yet_.
      def cancel!
        if hpp_payment? || adyen_cc_payment?
          if source.respond_to?(:requires_manual_refund?) && source.requires_manual_refund?
            log_manual_refund
          else
            process { payment_method.cancel response_code }
          end
        else
          super
        end
      end

      private

      def log_manual_refund
        message = I18n.t("solidus-adyen.manual_refund.log_message")
        record_response(
          OpenStruct.new(
            success?: false,
            message: message))
      end

      def process &block
        response = nil

        Spree::Payment.transaction do
          protect_from_connection_error do
            started_processing!
            response = yield(block)
            fail ActiveRecord::Rollback unless response.success?
          end
        end

        record_response(response)

        if response.success?
          # The payments controller's fire action expects a truthy value to
          # indicate success
          true
        else
          # this is done to be consistent with capture, but we might actually
          # want them to just return to the previous state
          gateway_error(response)
        end
      end

      def update_adyen_card_data
        safe_credit_cards = get_safe_cards
        return nil if safe_credit_cards.nil? || safe_credit_cards.empty?

        # Ensure we use the correct card we just created
        safe_credit_cards.sort_by! { |card| card[:creation_date] }
        safe_credit_card_data = safe_credit_cards.last

        source.update(
          gateway_customer_profile_id: safe_credit_card_data[:recurring_detail_reference],
          cc_type: safe_credit_card_data[:variant],
          last_digits: safe_credit_card_data[:card_number],
          month: "%02d" % safe_credit_card_data[:card_expiry_month],
          year: "%04d" % safe_credit_card_data[:card_expiry_year],
          name: safe_credit_card_data[:card_holder_name]
        )
      end

      def get_safe_cards
        response = payment_method.rest_client.list_recurring_details({
          merchant_account: payment_method.account_locator.by_order(order),
          shopper_reference: order.adyen_shopper_reference
        })

        if response.success? && !response.gateway_response.details.blank?
          response.gateway_response.details
        else
          log_entries.create!(details: response.to_yaml)
        end
      end

      def should_authorise?
        ratepay? && amount > 0
      end
    end
  end
end
