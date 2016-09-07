module Spree
  module Api
    class AdyenController < Spree::Api::BaseController
      before_action :find_order
      around_action :lock_order
      before_action :find_payment_method

      def hpp
        @brands = Spree::Adyen::HPP.payment_methods_from_directory(
          @order,
          @payment_method)

        render json: @brands
      end

      private

      def find_order
        @order = Spree::Order.find_by(number: order_id)
        authorize! :read, @order, order_token
      end

      def find_payment_method
        @payment_method = Spree::PaymentMethod.find_by(id: params[:payment_method_id])
      end
    end
  end
end