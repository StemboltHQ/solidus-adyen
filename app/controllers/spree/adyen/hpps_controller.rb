module Spree
  module Adyen
    class HppsController < StoreController
      load_resource :order, class: "Spree::Order", id_param: :order_id
      load_resource(
        :payment_method,
        class: "Spree::PaymentMethod",
        id_param: :payment_method_id)

      layout false

      def directory
        @brands = Spree::Adyen::HPP.payment_methods_from_directory(
          @order,
          @payment_method)

        respond_to do |format|
          format.html
          format.json { render json: @brands }
        end
      end
    end
  end
end
