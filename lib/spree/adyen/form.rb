require "json"

module Spree::Adyen::Form
  Form = Adyen::Form
  UrlHelper = Object.new.extend ActionView::Helpers::UrlHelper

  class << self
    def payment_methods_from_directory order, payment_method
      payment_methods(order, payment_method).fetch('paymentMethods')
    end


    def directory_url order, payment_method
      endpoint_url 'directory', order, payment_method
    end

    def details_url order, payment_method, directory_entry
      endpoint_url(
        'details', order, payment_method, directory_entry.slice('brandCode'))
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

      JSON.parse ::Net::HTTP.get url
    end

    def url payment_method, endpoint
      server = payment_method.preferences.fetch(:server)
      Form.url(server, endpoint)
    end

    def params order, payment_method
      Form.flat_payment_parameters default_params.
        merge(order_params order).
        merge(payment_method_params payment_method)
    end

    # TODO set this in the adyen config
    def default_params
      { ship_before_date: Date.tomorrow,
        session_validity: 10.minutes.from_now,
        recurring: false }
    end

    def order_params order
      { currency_code: order.currency,
        merchant_reference: order.number.to_s,
        country_code: order.billing_address.country.iso3,
        payment_amount: (order.total.to_f * 100).to_int }
    end

    def payment_method_params payment_method
      { merchant_account: payment_method.merchant_account,
        skin_code: payment_method.skin_code,
        shared_secret: payment_method.shared_secret }
    end
  end
end
