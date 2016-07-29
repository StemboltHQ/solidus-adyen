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
        after_create :authorize_payment, if: :authorizable_cc_payment?

        private

        # Performs and authorization call to Adyen for the payment
        # @raise [Spree::Core::GatewayError] if the encrypted card data is missing
        # @raise [Spree::Core::GatewayError] if the authorize call fails
        def authorize_payment
          response = authorize_new_payment

          unless response.success?
            raise Spree::Core::GatewayError.new(
              I18n.t(:credit_card_data_refused, scope: 'solidus-adyen')
            )
          end

          self.response_code = response.params[:psp_reference]
          save!
          update_stored_card_data
        end
      end

      # Spree::Payment#process will call purchase! for payment methods with
      # auto_capture enabled. Since we authorize credit cards in the payment
      # step already, we just need to capture the payment here.
      def purchase!
        if adyen_cc_payment?
          capture!
        else
          super
        end
      end

      # capture! :: bool | error
      def capture!
        if hpp_payment? || adyen_cc_payment?
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

      def authorize_new_payment
        # If this is a new credit card we should have the encrypted data
        if source.encrypted_data
          response = payment_method.provider.authorise_payment(
            order.number,
            price_data,
            shopper_data_from_order,
            encrypted_card_data,
            true,
          )
          # If the user selects an existing card, we have the profile ID
        elsif source.gateway_customer_profile_id
          response = payment_method.provider.authorise_recurring_payment(
            order.number,
            price_data,
            shopper_data_from_order,
            source.gateway_customer_profile_id,
            nil,
            false,
          )
        else
          raise Spree::Core::GatewayError.new(
            I18n.t(:missing_encrypted_data, scope: 'solidus-adyen')
          )
        end
      end

      def update_stored_card_data
        safe_credit_cards = get_safe_cards
        return nil if safe_credit_cards.nil? || safe_credit_cards.empty?

        # Ensure we use the correct card we just created
        safe_credit_cards.sort_by! { |card| card[:creation_date] }
        safe_credit_card_data = safe_credit_cards.last

        source.update(
          gateway_customer_profile_id: safe_credit_card_data[:recurring_detail_reference],
          cc_type: safe_credit_card_data[:variant],
          last_digits: safe_credit_card_data[:card][:number],
          month: "%02d" % safe_credit_card_data[:card][:expiry_date].month,
          year: "%04d" % safe_credit_card_data[:card][:expiry_date].year.to_s,
          name: safe_credit_card_data[:card][:holder_name]
        )
      end

      def get_safe_cards
        payment_method.provider.list_recurring_details(
          reference_number_from_order
        ).details
      end

      def reference_number_from_order
        order.user_id.to_s || order.number
      end

      # Solidus creates a $0 default payment during checkout using a previously
      # used credit card, which we should not create an authorization for.
      def authorizable_cc_payment?
        adyen_cc_payment? && amount != 0
      end

      def encrypted_card_data
        {
          encrypted: {
            json: source.encrypted_data
          }
        }
      end

      def shopper_data_from_order
        {
          reference: order.user_id.to_s || order.number,
          email: order.email,
          ip: order.last_ip_address,
          statement: order.number
        }
      end

      def price_data
        {
          value: money.cents,
          currency: currency
        }
      end
    end
  end
end
