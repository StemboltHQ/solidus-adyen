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
        success = Spree::Adyen::ConfirmHppPayment
                      .confirm(@order, @payment_method, adyen_permitted_params)

        if success
          handle_successful_payment
        else
          handle_failed_payment
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
            adyen_permitted_params,
            @payment_method.shared_secret
        )
          raise Spree::Adyen::InvalidSignatureError, 'Signature invalid!'
        end
      end

      def handle_successful_payment
        raise 'Missing method'
      end

      def handle_failed_payment
        raise 'Missing method'
      end

      def handle_signature_error(error)
        raise 'Missing method'
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
    end
  end
end
