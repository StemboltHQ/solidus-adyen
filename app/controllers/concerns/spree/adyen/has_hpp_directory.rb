module Spree
  module Adyen
    module HasHppDirectory
      extend ActiveSupport::Concern

      included do
        load_resource :order, class: 'Spree::Order', id_param: :order_id
        load_resource(
            :payment_method,
            class: 'Spree::PaymentMethod',
            id_param: :payment_method_id
        )

        before_action :init_brands, only: :directory
      end

      def directory
        raise 'Missing method'
      end

      private

      def init_brands
        @brands = Spree::Adyen::HPP.payment_methods_from_directory(
            @order,
            @payment_method
        )
      end
    end
  end
end
