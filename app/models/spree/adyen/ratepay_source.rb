module Spree
  module Adyen
    class RatepaySource < ::ActiveRecord::Base
      belongs_to :payment_method
      belongs_to :user, class_name: Spree.user_class, foreign_key: "user_id"
      has_one :payment, class_name: "Spree::Payment", as: :source
      has_many :notifications,
        class_name: "AdyenNotification",
        foreign_key: :merchant_reference,
        primary_key: :merchant_reference
    end
  end
end
