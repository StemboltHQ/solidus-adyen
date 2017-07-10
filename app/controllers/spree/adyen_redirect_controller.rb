module Spree
  class AdyenRedirectController < AdyenController
    include Spree::Adyen::CanConfirmPayment

    skip_before_action :verify_authenticity_token

    def authorise3d
      @payment = Spree::Payment.find_by(number: params[:payment_reference])
      @payment.request_env = request.env
      @order = @payment.order
      payment_method = @payment.payment_method
      begin
        payment_method.authorise_3d_secure_payment(@payment, adyen_3d_params)
        advance_to_confirm(@order)
        redirect_to checkout_state_path(@order.state)
      rescue Spree::Gateway::AdyenCreditCard::InvalidDetailsError
        handle_failed_payment
      end
    end

    private

    def advance_to_confirm(order)
      steps = order.checkout_steps
      return if steps.index("confirm") < (steps.index(order.state) || 0)

      until order.state == "confirm"
        order.next!
      end
    end

    def handle_failed_payment
      flash.notice = Spree.t(:payment_processing_failed)
      redirect_to checkout_state_path(@order.state)
    end

    def handle_successful_payment
      @current_order = nil
      flash.notice = Spree.t(:order_processed_successfully)
      flash['order_completed'] = true
      redirect_to order_path(@order)
    end

    def check_signature
      unless ::Adyen::HPP::Signature.verify(response_params, @payment_method.shared_secret)
        raise Spree::Adyen::InvalidSignatureError, 'Signature invalid!'
      end
    end

    # We pass the guest token and payment method id in, pipe seperated in the
    # merchantReturnData parameter so that we can recover the session.
    def restore_order
      guest_token, payment_method_id =
        params.fetch(:merchantReturnData).split("|")

      cookies.permanent.signed[:guest_token] = guest_token

      @payment_method = Spree::PaymentMethod.find(payment_method_id)

      @order = Spree::Order.find_by!(number: order_number)
    end

    # We receive `MD`, a session identifier, and `PaRes`, an
    # authentication response, from Adyen after 3d secure redirect
    def adyen_3d_params
      params.permit(:MD, :PaRes)
    end
  end
end
