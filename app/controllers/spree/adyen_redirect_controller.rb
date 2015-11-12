module Spree
  class AdyenRedirectController < StoreController
    before_filter :restore_session
    before_filter :check_signature, only: :confirm

    skip_before_filter :verify_authenticity_token

    # This is the entry point after an Adyen HPP payment is completed
    def confirm
      if @order.complete?
        confirm_order_already_completed
      else
        confirm_order_incomplete
      end
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

      if @order.complete
        redirect_to_order
      else
        #TODO void/cancel payment
        redirect_to checkout_state_path(@order.state)
      end
    end

    # If an authorization notification is received before the redirection the
    # payment is created there.In this case we just need to assign the addition
    # parameters received about the source.
    #
    # We do this because there is a chance that we never get redirected back
    # so we need to make sure we complete the payment and order.
    def confirm_order_already_completed
      payment = @order.payments.find_by(response_code: psp_reference)
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

      @order =
        Spree::Order.
        find_by!(guest_token: cookies.signed[:guest_token])
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

    def psp_reference
      params[:pspReference]
    end
  end
end
