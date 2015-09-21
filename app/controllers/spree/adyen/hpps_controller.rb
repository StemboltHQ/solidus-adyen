module Spree
  class Adyen::HppsController < ::ActionController::Base
    load_resource :order, class: 'Spree::Order', id_param: :order_id
    load_resource :payment_method, class: 'Spree::PaymentMethod', id_param: :payment_method_id

    def directory
      @brands = Adyen::Form.payment_methods_from_directory @order, @payment_method
    end
  end
end
