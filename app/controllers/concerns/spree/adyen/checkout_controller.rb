module Spree
  module Adyen
    module CheckoutController
      def self.prepended(mod)
        mod.before_action :set_payment_request_env, only: :update
      end

      def update
        if SolidusSupport.solidus_gem_version >= Gem::Version.new("2.2.0")
          update_v2_2
        else
          update_v1_2
        end
      end

      private

      def update_v2_2
        if update_order

          assign_temp_address

          unless transition_forward
            return if process_adyen_3ds
            redirect_on_failure
            return
          end

          if @order.completed?
            finalize_order
          else
            send_to_next_state
          end

        else
          render :edit
        end
      end

      def update_v1_2
        if Spree::OrderUpdateAttributes.new(@order, update_params, request_env: request.headers.env).apply
          @order.temporary_address = !params[:save_user_address]

          success = if @order.state == 'confirm'
            @order.complete
          else
            @order.next
          end
          if !success
            return if process_adyen_3ds
            flash[:error] = @order.errors.full_messages.join("\n")
            redirect_to(checkout_state_path(@order.state)) && return
          end

          if @order.completed?
            @current_order = nil
            flash.notice = Spree.t(:order_processed_successfully)
            flash['order_completed'] = true
            redirect_to completion_route
          else
            redirect_to checkout_state_path(@order.state)
          end
        else
          render :edit
        end
      end

      def process_adyen_3ds
        if @order.reload.payment? && payment = @order.payments.find(&:redirect_response)
          @redirect_response = payment.redirect_response
          render 'spree/checkout/payment/adyen_3ds_form', layout: false
          true
        end
      end

      def set_payment_request_env
        @order.payments.each { |payment| payment.request_env = request.headers.env }
      end
    end
  end
end
