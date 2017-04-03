module Spree
  module Adyen
    module HPP
      class Params
        # This class is intended to provide default parameters for HPP payment
        # methods. To change the default behaviour, users can create a custom
        # class that responds to #params and configure it to be used in an
        # initializer (See Spree::Adyen::HPP::Configuration).

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

        def authorise_invoice(dob)
          authorisation_request.
            merge(shopper_details(dob)).
            merge(address_params).
            merge(additional_data: openinvoice_params)
        end

        private

        def default_params
          { session_validity: 10.minutes.from_now.utc,
            recurring: false
          }
        end

        def authorisation_request
          {
            merchant_account: @payment_method.account_locator.by_order(@order),
            reference: @order.number,
            amount: {
              currency: @order.currency,
              value: @order.display_total.money.cents
            }
          }
        end

        def merchant_return_data
          { merchant_return_data: [@order.guest_token, @payment_method.id].join("|") }
        end

        def order_params
          { currency_code: @order.currency,
            merchant_reference: @order.number.to_s,
            country_code: @order.billing_address.country.iso,
            payment_amount: (@order.total * 100).to_int,
            shopper_locale: I18n.locale.to_s.gsub("-", "_"),
            shopper_email: @order.email,
          }
        end

        def payment_method_params
          { merchant_account: @payment_method.account_locator.by_order(@order),
            skin_code: @payment_method.skin_code,
            shared_secret: @payment_method.shared_secret,
            ship_before_date: @payment_method.ship_before_date
          }
        end

        def shopper_details dob
          address = @order.ship_address
          {
            shopper_email: @order.email,
            shopper_reference: @order.user_id.to_s.presence || @order.number,
            shopper_name: {
              first_name: address.firstname,
              infix: "",
              last_name: address.lastname,
              gender: "UNKNOWN"
            },
            shopper_i_p: @order.last_ip_address,
            shopper_country: address.country.iso,
            date_of_birth: dob,
            telephone_number: address.phone
          }
        end

        def address_params
          {
            delivery_address: address_fields,
            billing_address: address_fields,
          }
        end

        # In Solidus we store the house number and street name together in
        # address1. This splits address1 on the first space and assumes the
        # first part is the number and the second part the street name.
        #
        # Since this is frequently not appropriate, this behaviour should be
        # overridden using a custom params class (see: Spree::Adyen::HPP::Configuration)
        def address_fields
          address = @order.ship_address
          house_number, street = address.address1.split(" ", 2)
          {
            street: street,
            house_number_or_name: house_number,
            city: address.city,
            postal_code: address.zipcode,
            country: address.country.iso,
          }
        end

        def openinvoice_params
          Spree::Adyen::HPP.configuration.invoice_class.new(@order).request_params
        end
      end
    end
  end
end
