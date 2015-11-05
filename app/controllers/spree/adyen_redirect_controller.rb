module Spree
  class AdyenRedirectController < StoreController
    before_filter :check_signature, only: :confirm

    skip_before_filter :verify_authenticity_token

    # This is the entry point after an Adyen HPP payment is completed
    def confirm
      source = Adyen::HppSource.new(source_params(params))

      unless source.authorised?
        flash.notice = Spree.t(:payment_processing_failed)
        redirect_to checkout_state_path(current_order.state)
        return
      end

      order = Spree::Order.find_by(number: params[:merchantReference]) ||
                current_order ||
                raise(ActiveRecord::RecordNotFound)

      # payment is created in a 'checkout' state so that the payment method
      # can attempt to auth it. The payment of course is already auth'd and
      # adyen hpp's authorize implementation just returns a dummy response.
      payment =
        order.payments.create!(
          amount: order.total,
          payment_method: payment_method,
          source: source,
          response_code: params[:pspReference],
          state: "checkout",
          # Order is explicitly defined here because as of writing the
          # Order -> Payments association does not have the inverse of defined
          # when we call `order.complete` below payment.order will still
          # refer to a previous state of the record.
          #
          # If the payment is auto captured only then the payment will completed
          # in `process_outstanding!`, and because Payment calls
          # .order.update_totals after save the order is saved with its
          # previous values, causing payment_state and shipment_state to revert
          # to nil.
          order: order
        )

      if order.complete
        # We may have already recieved the authorization notification, so process
        # it now
        Spree::Adyen::NotificationProcessor.process_outstanding!(payment)

        flash.notice = Spree.t(:current_order_processed_successfully)
        redirect_to order_path(order)
      else
        #TODO void/cancel payment
        redirect_to checkout_state_path(order.state)
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
