module Spree
  module Adyen
    module HPP
      class Params
        # This class is intended to provide default parameters for HPP payment
        # methods. To change the default behaviour, users can create a custom
        # class that responds to #params and configure it to be used in an
        # initializer (See Spree::Adyen::Form::Configuration).

        def initialize order, payment_method
          @order = order
          @payment_method = payment_method
        end

        def params
          default_params.
            merge(order_params).
            merge(payment_method_params).
            merge(merchant_return_data)
        end

        private

        def default_params
          { session_validity: 10.minutes.from_now.utc,
            recurring: false
          }
        end

        def merchant_return_data
          { merchantReturnData: [
              @order.guest_token,
              @payment_method.id
            ].join("|")
          }
        end

        def order_params
          { currency_code: @order.currency,
            merchant_reference: @order.number.to_s,
            country_code: @order.billing_address.country.iso,
            payment_amount: (@order.total * 100).to_int,
            shopper_locale: I18n.locale.to_s.gsub("-", "_"),
            shopper_email: @order.email
          }
        end

        def payment_method_params
          { merchant_account: @payment_method.merchant_account,
            skin_code: @payment_method.skin_code,
            shared_secret: @payment_method.shared_secret,
            ship_before_date: @payment_method.ship_before_date
          }
        end
      end
    end
  end
end
