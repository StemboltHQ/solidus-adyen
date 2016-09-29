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

      attr_accessor :dob_day, :dob_month, :dob_year

      # Adyen require
      def date_of_birth
        "#{dob_year}-#{dob_day}-#{dob_month}"
      end
    end
  end
end
