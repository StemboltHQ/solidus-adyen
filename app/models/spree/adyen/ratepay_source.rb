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

      attr_accessor :dob_day, :dob_month, :dob_year, :device_token

      # Formats the date of birth fields how they are accepted by Adyen
      #
      # @return [String] The DOB in the format yyyy-dd-mm
      def date_of_birth
        "#{dob_year}-#{dob_day}-#{dob_month}"
      end

      # Checks if all the date of birth fields have been set
      #
      # @return [Bool] true if all DOB fields are set, false otherwise
      def has_dob?
        [dob_day, dob_month, dob_year].all?(&:present?)
      end
    end
  end
end
