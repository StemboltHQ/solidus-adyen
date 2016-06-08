module Spree
  class AdyenRedirectController < StoreController
    before_filter :restore_session
    before_filter :check_signature, only: :confirm

    skip_before_filter :verify_authenticity_token

    # This is the entry point after an Adyen HPP payment is completed
    def confirm
      # Reload order as it might have changed since previously loading it
      # from an auth notification coming in at the same time.
      # This and the notification processing need to have a lock on the order
      # as they both decide what to do based on whether or not the order is
      # complete.
      Spree::OrderMutex.with_lock!(@order) do
        if @order.complete?
          confirm_order_already_completed
        else
          confirm_order_incomplete
        end
      end

    rescue Spree::OrderMutex::LockFailed
      render :confirm
    end

    private

    def confirm_order_incomplete
      source = Adyen::HppSource.new(source_params)

      unless source.authorised?
        flash.notice = Spree.t(:payment_processing_failed)
        redirect_to checkout_state_path(@order.state)
        return
      end

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
        redirect_to_order
      else
        #TODO void/cancel payment
        redirect_to checkout_state_path(@order.state)
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
        payment =
          @order.payments.where(source_type: "Spree::Adyen::HppSource").last
      end

      payment.source.update(source_params)

      redirect_to_order
    end

    def redirect_to_order
      flash.notice = Spree.t(:order_processed_successfully)
      redirect_to order_path(@order)
    end

    def check_signature
      unless ::Adyen::Form.redirect_signature_check(params, @payment_method.shared_secret)
        raise "Payment Method not found."
      end
    end

    # We pass the guest token and payment method id in, pipe seperated in the
    # merchantReturnData parameter so that we can recover the session.
    def restore_session
      guest_token, payment_method_id =
        params.fetch(:merchantReturnData).split("|")

      cookies.permanent.signed[:guest_token] = guest_token

      @payment_method = Spree::PaymentMethod.find(payment_method_id)

      @order = Spree::Order.find_by!(number: order_number)
    end

    def source_params
      params.permit(
        :authResult,
        :pspReference,
        :merchantReference,
        :skinCode,
        :merchantSig,
        :paymentMethod,
        :shopperLocale,
        :merchantReturnData)
    end

    def order_number
      params[:merchantReference]
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
