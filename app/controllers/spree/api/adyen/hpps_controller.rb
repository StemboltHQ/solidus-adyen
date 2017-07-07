module Spree
  module Api
    module Adyen
      class HppsController < Spree::Api::BaseController
        load_resource :order, class: "Spree::Order", id_param: :order_id
        load_resource :payment_method, class: "Spree::PaymentMethod", id_param: :payment_method_id

        def directory
          render json: brands
        end

        private

        def brands
          Spree::Adyen::HPP.payment_methods_from_directory @order, @payment_method
        end
      end
    end
  end
end
