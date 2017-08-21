module Spree
  module Adyen
    class RedirectResponse < ::ActiveRecord::Base
      belongs_to :payment, class_name: "Spree::Payment", inverse_of: :redirect_response
    end
  end
end
