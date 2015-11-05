# This models the response that is received after a user is redirected from the
# Adyen Hosted Payment Pages. It's used as the the source for the Spree::Payment
# and keeps track of the messages received from the notifications end point.
#
# Attributes defined are dervived from the docs:
# https://docs.adyen.com/display/TD/HPP+payment+response
#
# Information about when certain action are valid:
# https://docs.adyen.com/display/TD/HPP+modifications
module Spree::Adyen
  class HppSource < ::ActiveRecord::Base
    MANUALLY_REFUNDABLE = [
      "directEbanking"
    ].freeze

    PENDING = "PENDING".freeze
    AUTHORISED = "AUTHORISED".freeze
    REFUSED = "REFUSED".freeze
    CANCELLED = "CANCELLED".freeze

    # support updates from capital-cased responses, which is what adyen gives
    # us
    alias_attribute :authResult, :auth_result
    alias_attribute :pspReference, :psp_reference
    alias_attribute :merchantReference, :merchant_reference
    alias_attribute :skinCode, :skin_code
    alias_attribute :merchantSig, :merchant_sig
    alias_attribute :paymentMethod, :payment_method
    alias_attribute :shopperLocale, :shopper_locale
    alias_attribute :merchantReturnData, :merchant_return_data

    belongs_to :order, class_name: "Spree::Order",
      primary_key: :number,
      foreign_key: :merchant_reference

    has_one :payment, class_name: "Spree::Payment", as: :source

    # FIXME should change this to find the auth notification by order number,
    # then all notification that have a original ref that matches it's psp
    has_many :notifications,
      class_name: "AdyenNotification",
      foreign_key: :merchant_reference,
      primary_key: :merchant_reference

    def can_capture? payment
      payment.uncaptured_amount != 0.0
    end

    def actions
      if mutable?
        authorised_actions
      else
        []
      end
    end

    def can_cancel? payment
      payment.refunds.empty?
    end

    def requires_manual_refund?
      MANUALLY_REFUNDABLE.include?(payment_method)
    end

    def authorised?
      # Many banks return pending, this is considered a valid response and
      # the order should proceed.
      [PENDING, AUTHORISED].include? auth_result
    end

    private
    def mutable?
      !payment.void? && !payment.processing?
    end

    # authorised_actions :: [String] | []
    def authorised_actions
      if auth_notification
        auth_notification.
          actions.map(&method(:transform_action))

      else
        []

      end
    end

    def transform_action action
      if action == "refund"
        # return credit so that we go to the new refund action
        "credit"
      else
        action
      end
    end

    def auth_notification
      notifications.processed.authorisation.last
    end
  end
end
