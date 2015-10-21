module Spree
  class AdyenRedirectController < StoreController
    before_filter :check_signature, only: :confirm

    skip_before_filter :verify_authenticity_token

    # This is the entry point after an Adyen HPP payment is completed
    def confirm
      order = current_order
      #  TODO This is not technically correct
      #  if the result is pending we might get a response later in the
      #  callback saying the order is ready to be captured. It's probably
      #  safe(?)
      #  From the docs:
      #  When authResult equals PENDING, ERROR or CANCELLED, the pspReference
      #  may not yet be known; therefore, it may be empty or not included.
      unless authorized?
        flash.notice = Spree.t(:payment_processing_failed)
        redirect_to checkout_state_path(order.state) and return
      end

      # payment is created in a 'checkout' state so that the payment method
      # can attempt to auth it. The payment of course is already auth'd and
      # adyen hpp's authorize implementation just returns a dummy response.
      order.payments.create!(
        amount: order.total,
        payment_method: payment_method,
        response_code: params[:pspReference],
        state: 'checkout'
      ) do |payment|
        payment.source = Adyen::HppSource.create!(source_params(params))
      end

      if order.complete
        flash.notice = Spree.t(:order_processed_successfully)
        redirect_to order_path(order, token: order.guest_token)
      else
        redirect_to checkout_state_path(order.state)
      end
    end

    private

    def authorized?
      params[:authResult] == "AUTHORISED"
    end

    def check_signature
      unless ::Adyen::Form.redirect_signature_check(params, payment_method.shared_secret)
        raise "Payment Method not found."
      end
    end

    # TODO find a way to send the payment method id to Adyen servers and get
    # it back here to make sure we find the right payment method
    def payment_method
      @payment_method ||= Gateway::AdyenHPP.last # find(params[:merchantReturnData])
    end

    def source_params params
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
  end
end
