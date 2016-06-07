require "json"

module Spree
  module Adyen
    module HPP
      HPP = ::Adyen::HPP
      UrlHelper = Object.new.extend ActionView::Helpers::UrlHelper

      class << self
        attr_accessor :configuration

        def configure
          self.configuration ||= Spree::Adyen::HPP::Configuration.new
          yield(configuration)
        end

        def payment_methods_from_directory order, payment_method
          payment_methods(order, payment_method)
        end

        def pay_url order, payment_method
          endpoint_url "pay", order, payment_method
        end

        def select_url order, payment_method
          endpoint_url "select", order, payment_method
        end

        def directory_url order, payment_method
          endpoint_url "directory", order, payment_method
        end

        def details_url order, payment_method, brand_code
          endpoint_url(
            "details", order, payment_method, { brandCode: brand_code })
        end

        def details_url_with_issuer order, payment_method, brand_code, issuer_id
          endpoint_url(
            "details",
            order,
            payment_method,
            {
              brandCode: brand_code,
              issuerId: issuer_id
            }
          )
        end

        def endpoint_url endpoint, order, payment_method, opts = {}
          adyen_request = hpp_request order, payment_method, opts

          URI::parse("#{adyen_request.url(endpoint)}?#{adyen_request.flat_payment_parameters.to_query}")
        end

        private
        def hpp_request order, payment_method, opts
          server = payment_method.preferences.fetch(:server)
          params_config = configuration.params_class.new(order, payment_method)
          parameters = params_config.params.merge(opts)

          HPP::Request.new(parameters, environment: server,
                                       skin: { skin_code: payment_method.skin_code },
                                       shared_secret: payment_method.shared_secret)
        end

        def payment_methods order, payment_method
          url = directory_url(order, payment_method)

          form_payment_methods_and_urls(
            JSON.parse(::Net::HTTP.get(url)),
            order,
            payment_method
          )
        end

        def form_payment_methods_and_urls response, order, payment_method
          response.fetch("paymentMethods").map do |brand|
            next unless payment_method_allows_brand_code?(payment_method, brand['brandCode'])

            issuers = brand.fetch("issuers", []).map do |issuer|
              form_issuer(issuer, order, payment_method, brand)
            end

            form_payment_method(brand, order, payment_method, issuers)
          end.compact
        end

        def form_issuer issuer, order, payment_method, brand
          {
            name: issuer["name"],
            payment_url: details_url_with_issuer(
              order,
              payment_method,
              brand["brandCode"],
              issuer["issuerId"]
            ).to_s
          }
        end

        def form_payment_method brand, order, payment_method, issuers
          {
            brand_code: brand["brandCode"],
            name: brand["name"],
            payment_url: details_url(
              order,
              payment_method,
              brand["brandCode"]
            ).to_s,
            issuers: issuers
          }
        end

        def payment_method_allows_brand_code? payment_method, brand_code
          return true if payment_method.restricted_brand_codes.empty?

          payment_method.restricted_brand_codes.include?(brand_code)
        end
      end
    end
  end
end
