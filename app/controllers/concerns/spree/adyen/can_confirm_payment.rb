module Spree
  module Adyen
    module CanConfirmPayment
      extend ActiveSupport::Concern

      included do
        before_action :restore_order, only: :confirm
        before_action :check_signature, only: :confirm

        rescue_from(
            Spree::Adyen::InvalidSignatureError,
            with: :handle_signature_error
        )
      end

      # This is the entry point after an Adyen HPP payment is completed
      def confirm
        # Reload order as it might have changed since previously loading it
        # from an auth notification coming in at the same time.
        # This and the notification processing need to have a lock on the order
        # as they both decide what to do based on whether or not the order is
        # complete.
        @order.with_lock do
          if @order.complete?
            confirm_order_already_completed
          else
            confirm_order_incomplete
          end
        end
      end

      private

      def restore_order
        payment_method_id = params.fetch(:merchantReturnData).split('|').last

        @payment_method = Spree::PaymentMethod.find(payment_method_id)
        @order = Spree::Order.find_by!(number: order_number)
      end

      def check_signature
        unless ::Adyen::HPP::Signature.verify(
            response_params,
            @payment_method.shared_secret
        )
          raise Spree::Adyen::InvalidSignatureError, 'Signature invalid!'
        end
      end

      # If an authorization notification is received before the redirection the
      # payment is created there. In this case we just need to assign the addition
      # parameters received about the source.
      #
      # We do this because there is a chance that we never get redirected back
      # so we need to make sure we complete the payment and order.
      def confirm_order_already_completed
        if psp_reference
          payment = @order.payments.find_by!(response_code: psp_reference)
        else
          # If no psp_reference is present but the order is complete then the
          # notification must have completed the order and created the payment.
          # Therefore select the last Adyen payment.
          payment = @order.payments.where(
              source_type: 'Spree::Adyen::HppSource'
          ).last
        end

        payment.source.update(source_params)

        handle_successful_payment
      end

      def confirm_order_incomplete
        source = Spree::Adyen::HppSource.new(source_params)

        return handle_failed_payment unless source.authorised?

        # payment is created in a 'checkout' state so that the payment method
        # can attempt to auth it. The payment of course is already auth'd and
        # adyen hpp's authorize implementation just returns a dummy response.
        @order.payments.create!(
            amount: @order.total,
            payment_method: @payment_method,
            source: source,
            response_code: psp_reference,
            state: "checkout"
        )

        if complete
          handle_successful_payment
        else
          #TODO void/cancel payment
          handle_failed_payment
        end
      end

      def handle_successful_payment
        raise 'Missing method'
      end

      def handle_failed_payment
        raise 'Missing method'
      end

      # @param [Spree::Adyen::InvalidSignatureError] error
      def handle_signature_error(error)
        raise 'Missing method'
      end

      def source_params
        adyen_permitted_params
      end

      def response_params
        adyen_permitted_params
      end

      def adyen_permitted_params
        params.permit(
            :authResult,
            :merchantReference,
            :merchantReturnData,
            :merchantSig,
            :paymentMethod,
            :pspReference,
            :shopperLocale,
            :skinCode
        )
      end

      def order_number
        params[:merchantReference]
      end

      def psp_reference
        params[:pspReference]
      end

      def auth_result
        params[:authResult]
      end

      def complete
        @order.contents.advance
        @order.complete
      end
    end
  end
end
