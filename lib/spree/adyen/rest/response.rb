module Spree
  module Adyen
    module REST
      module Response
        def success?
          @http_response.is_a?(Net::HTTPSuccess)
        end
      end
    end
  end
end
