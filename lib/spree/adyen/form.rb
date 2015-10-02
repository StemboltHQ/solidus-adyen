require "json"

module Spree::Adyen::Form
  Form = Adyen::Form
  UrlHelper = Object.new.extend ActionView::Helpers::UrlHelper

  class << self
    def payment_methods_from_directory order, payment_method
      payment_methods(order, payment_method)
    end

    def select_url order, payment_method
      endpoint_url 'select', order, payment_method
    end

    def directory_url order, payment_method
      endpoint_url 'directory', order, payment_method
    end

    def details_url order, payment_method, directory_entry
      endpoint_url(
        'details', order, payment_method, directory_entry.slice('brandCode'))
    end

    def details_url_with_issuer order, payment_method, directory_entry, issuer
      endpoint_url(
        'details',
        order,
        payment_method,
        {
          brandCode: directory_entry['brandCode'],
          issuerId: issuer['issuerId']
        }
      )
    end

    def endpoint_url endpoint, order, payment_method, opts = {}
      base = URI::parse(url payment_method, endpoint)

      URI::HTTPS.build(
        host: base.host,
        path: base.path,
        query: params(order, payment_method).merge(opts).to_query)
    end

    private
    def payment_methods order, payment_method
      url = ::Spree::Adyen::Form.directory_url(order, payment_method)

      form_payment_methods_and_urls(
        JSON.parse(::Net::HTTP.get(url)).fetch('paymentMethods'),
        order,
        payment_method
      )
    end

    def url payment_method, endpoint
      server = payment_method.preferences.fetch(:server)
      Form.url(server, endpoint)
    end

    def form_payment_methods_and_urls(response, order, payment_method)
      payment_methods = []
      response.each do |brand|
        if brand['issuers']
          issuers = []
          brand['issuers'].each do |issuer|
            issuers << {
              name: issuer['name'],
              payment_url: Spree::Adyen::Form.details_url_with_issuer(
                order,
                payment_method,
                brand,
                issuer
              ).to_s
            }
          end
          payment_methods << {
            brand_code: brand['brandCode'],
            name: brand['name'],
            payment_url: Spree::Adyen::Form.details_url(
              order,
              payment_method,
              brand
            ).to_s,
            issuers: issuers
          }
        else
          payment_methods << {
            brand_code: brand['brandCode'],
            name: brand['name'],
            payment_url: Spree::Adyen::Form.details_url(
              order,
              payment_method,
              brand
            ).to_s
          }
        end
      end
      payment_methods
    end

    def params order, payment_method
      Form.flat_payment_parameters default_params.
        merge(order_params order).
        merge(payment_method_params payment_method)
    end

    # TODO set this in the adyen config
    def default_params
      { session_validity: 10.minutes.from_now,
        recurring: false }
    end

    def order_params order
      { currency_code: order.currency,
        merchant_reference: order.number.to_s,
        country_code: order.billing_address.country.iso,
        payment_amount: (order.total.to_f * 100).to_int }
    end

    def payment_method_params payment_method
      { merchant_account: payment_method.merchant_account,
        skin_code: payment_method.skin_code,
        shared_secret: payment_method.shared_secret,
        ship_before_date: payment_method.ship_before_date }
    end
  end
end
