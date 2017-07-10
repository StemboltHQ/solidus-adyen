module Spree::Adyen
  # Class responsible for processing HPP order confirmations.
  class ConfirmHppPayment

    def self.confirm(order, payment_method, source_params)
      @order = order
      @payment_method = payment_method
      @source_params = source_params

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

    private

    # If an authorization notification is received before the redirection the
    # payment is created there. In this case we just need to assign the addition
    # parameters received about the source.
    #
    # We do this because there is a chance that we never get redirected back
    # so we need to make sure we complete the payment and order.
    def self.confirm_order_already_completed
      if @source_params[:pspReference]
        payment = @order
                      .payments
                      .find_by!(response_code: @source_params[:pspReference])
      else
        # If no psp_reference is present but the order is complete then the
        # notification must have completed the order and created the payment.
        # Therefore select the last Adyen payment.
        payment = @order.payments.where(
            source_type: 'Spree::Adyen::HppSource'
        ).last
      end

      payment.source.update(source_params)

      true
    end

    def self.confirm_order_incomplete
      source = Spree::Adyen::HppSource.new(@source_params)

      return false unless source.authorised?

      # payment is created in a 'checkout' state so that the payment method
      # can attempt to auth it. The payment of course is already auth'd and
      # adyen hpp's authorize implementation just returns a dummy response.
      @order.payments.create!(
          amount: @order.total,
          payment_method: @payment_method,
          source: source,
          response_code: @source_params[:pspReference],
          state: 'checkout'
      )

      complete
    end

    def self.complete
      @order.contents.advance
      @order.complete
    end
  end
end
