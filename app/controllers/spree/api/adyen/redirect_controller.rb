module Spree
  module Api
    module Adyen
      class RedirectController < Spree::Api::BaseController
        include Spree::Adyen::CanConfirmPayment

        def handle_successful_payment
          render(
              json: {
                  redirect: order_path(@order)
              },
              status: 200
          )
        end

        def handle_failed_payment
          render(
              json: {
                  errors: [auth_result],
                  type: 'payment_failed',
                  redirect: checkout_state_path(@order)
              },
              status: 422
          )
        end

        def handle_signature_error(error)
          render(
              json: {
                  errors: [error.message],
                  type: 'invalid_signature',
                  redirect: checkout_state_path(@order)
              },
              status: 422
          )
        end

        def auth_result
          params[:authResult]
        end

      end
    end
  end
end
