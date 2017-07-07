module Spree
  module Api
    module Adyen
      class RedirectController < Spree::Api::BaseController
        before_action :restore_order, only: :confirm
        before_action :check_signature, only: :confirm

        def confirm
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
          guest_token, payment_method_id = params.fetch(:merchantReturnData)
                                               .split('|')

          @payment_method = Spree::PaymentMethod.find(payment_method_id)
          @order = Spree::Order.find_by!(guest_token: guest_token)
        end

        def check_signature
          unless ::Adyen::HPP::Signature.verify(response_params, @payment_method.shared_secret)
            raise 'Payment Method not found.'
          end
        end

        def confirm_order_already_completed
          if psp_reference
            payment = @order.payments.find_by!(response_code: psp_reference)
          else
            payment = @order.payments.where(source_type: 'Spree::Adyen::HppSource').last
          end

          payment.source.update(source_params)

          redirect_to_order
        end

        def redirect_to_order
          render json: order_path(@order)
        end

        def confirm_order_incomplete
          source = Spree::Adyen::HppSource.new(source_params)

          return handle_failed_redirect unless source.authorised?

          @order.payments.create!(
              amount: @order.total,
              payment_method: @payment_method,
              source: source,
              response_code: psp_reference,
              state: "checkout"
          )

          if complete
            redirect_to_order
          else
            handle_failed_redirect
          end
        end

        def handle_failed_redirect
          render json: checkout_state_path(@order.state)
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
              :skinCode)
        end

        def psp_reference
          params[:pspReference]
        end

        def complete
          @order.contents.advance
          @order.complete
        end
      end
    end
  end
end
