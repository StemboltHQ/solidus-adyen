module Spree
  module Api
    module Adyen
      class HppsController < Spree::Api::BaseController
        load_resource :order, class: "Spree::Order", id_param: :order_id
        load_resource :payment_method, class: "Spree::PaymentMethod", id_param: :payment_method_id

        def directory
          return render :json => {:error => "payment-method-not-found"}.to_json, :status => 404 if @payment_method.nil?
          return render :json => {:error => "order-not-found"}.to_json, :status => 404 if @order.nil?

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
