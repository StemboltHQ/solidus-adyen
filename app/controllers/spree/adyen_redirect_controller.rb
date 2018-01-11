module Spree
  class AdyenRedirectController < AdyenController
    before_action :restore_session, only: :confirm
    before_action :check_signature, only: :confirm

    skip_before_action :verify_authenticity_token

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

    # This is the entry point after returning from the 3DS page for credit cards
    # that support it. MD is a unique payment session identifier returned
    # by the card issuer.
    def authorise3d
      payment = Spree::Adyen::RedirectResponse.find_by(md: params[:MD]).payment
      payment.request_env = request.env
      payment_method = payment.payment_method
      @order = payment.order

      payment_method.authorize_3d_secure_payment(payment, adyen_3d_params)
      payment.capture! if payment_method.auto_capture

      if complete
        redirect_to_order
      else
        redirect_to checkout_state_path(@order.state)
      end

      rescue Spree::Core::GatewayError
        handle_failed_redirect
    end

    private

    def handle_failed_redirect
      flash.notice = Spree.t(:payment_processing_failed)
      redirect_to checkout_state_path(@order.state)
    end

    def confirm_order_incomplete
      source = Adyen::HppSource.new(source_params)

      return handle_failed_redirect unless source.authorised?

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
      @current_order = nil
      flash.notice = Spree.t(:order_processed_successfully)
      flash['order_completed'] = true
      redirect_to order_path(@order)
    end

    def check_signature
      unless ::Adyen::HPP::Signature.verify(response_params.to_h, @payment_method.shared_secret)
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
      adyen_permitted_params
    end

    def response_params
      adyen_permitted_params
    end

    # We receive `MD`, a session identifier, and `PaRes`, an
    # authentication response, from Adyen after 3d secure redirect
    def adyen_3d_params
      params.permit(:MD, :PaRes)
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
