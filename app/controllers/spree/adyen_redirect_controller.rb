module Spree
  class AdyenRedirectController < StoreController
    PENDING = "PENDING"
    AUTHORIZED = "AUTHORISED"
    REFUSED = "REFUSED"
    CANCELLED = "CANCELLED"

    before_filter :check_signature, only: :confirm

    skip_before_filter :verify_authenticity_token

    # This is the entry point after an Adyen HPP payment is completed
    def confirm
      auth_result = params["authResult"]

      unless [PENDING, AUTHORIZED].include? auth_result
        flash.notice = Spree.t(:payment_processing_failed)
        redirect_to checkout_state_path(current_order.state)
        return
      end

      # payment is created in a 'checkout' state so that the payment method
      # can attempt to auth it. The payment of course is already auth'd and
      # adyen hpp's authorize implementation just returns a dummy response.
      current_order.payments.create!(
        amount: current_order.total,
        payment_method: payment_method,
        response_code: params[:pspReference],
        state: 'checkout'
      ) do |payment|
        payment.source = Adyen::HppSource.create!(source_params(params))
      end

      if current_order.complete
        flash.notice = Spree.t(:current_order_processed_successfully)
        redirect_to order_path(current_order)
      else
        #TODO void/cancel payment
        redirect_to checkout_state_path(current_order.state)
      end
    end

    private

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
