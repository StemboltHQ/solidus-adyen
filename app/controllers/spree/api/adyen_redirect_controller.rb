module Spree
  module Api
    class AdyenRedirectController < Spree::Api::BaseController
      before_action :find_order
      around_action :lock_order
      before_action :find_payment_method
      before_filter :check_signature, only: :confirm

      def confirm
        if @order.complete?
          confirm_order_already_completed
        else
          confirm_order_incomplete
        end
      end

      private

      def confirm_order_already_completed
        if psp_reference
          payment = @order.payments.find_by!(response_code: psp_reference)
        else
          payment = @order.payments.where(source_type: "Spree::Adyen::HppSource").last
        end

        payment.source.update(permitted_params)

        respond_with(@order, default_template: 'spree/api/orders/show', status: :ok)
      end

      def confirm_order_incomplete
        source = Adyen::HppSource.new(permitted_params)

        return handle_failure unless source.authorised?

        @order.payments.create!(
          amount: @order.total,
          payment_method: @payment_method,
          source: source,
          response_code: psp_reference,
          state: "checkout"
        )

        if complete
          respond_with(@order, default_template: 'spree/api/orders/show', status: :ok)
        else
          respond_with(@order, default_template: 'spree/api/orders/show', status: :unprocessable_entity)
        end
      end

      def handle_failure
        respond_with(@order, default_template: 'spree/api/orders/show', status: 422)
      end

      def find_order
        @order = Spree::Order.find_by!(number: order_id)
        authorize! :read, @order, order_token
      end

      def find_payment_method
        _, payment_method_id = params[:merchantReturnData].split("|")
        @payment_method = Spree::PaymentMethod.find_by!(id: payment_method_id)
      end

      def check_signature
        unless ::Adyen::HPP::Signature.verify(permitted_params, @payment_method.shared_secret)
          raise "Payment Method not found."
        end
      end

      def permitted_params
        params.permit(
          :authResult,
          :merchantReference,
          :merchantReturnData,
          :merchantSig,
          :paymentMethod,
          :pspReference,
          :shopperLocale,
          :skinCode)
      end

      def complete
        @order.contents.advance
        @order.complete
      end

      def psp_reference
        params[:pspReference]
      end
    end
  end
end
