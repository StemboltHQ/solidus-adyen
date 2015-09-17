require "json"

module Spree::Adyen::Form
  Form = Adyen::Form

  class << self
    def payment_methods_from_directory params
      payment_methods(params.dup).map do |method|
        method.merge("url" => url('details', params.merge(brand_code: method['brandCode'])).to_s)
      end
    end

    private
    def url endpoint, params
      # this is bad and I feel bad
      URI Form.redirect_url(params).sub('select.shtml', "#{endpoint}.shtml")
    end

    def payment_methods params
      response(params).fetch('paymentMethods', [])
    end

    def response params
      JSON.parse Net::HTTP.get url('directory', params)
    end
  end
end
