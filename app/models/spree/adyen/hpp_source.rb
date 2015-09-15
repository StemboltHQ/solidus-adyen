# This models the response that is received after a user is redirected from the
# Adyen Hosted Payment Pages. It's used as the the source for the Spree::Payment
# and keeps track of the messages received from the notifications end point.
#
# Attributes defined are dervived from the docs:
# https://docs.adyen.com/display/TD/HPP+payment+response
#
# Information about when certain action are valid:
# https://docs.adyen.com/display/TD/HPP+modifications
class Spree::Adyen::HppSource < ActiveRecord::Base
  # support updates from capital-cased responses, which is what adyen gives us
  alias_attribute :authResult, :auth_result
  alias_attribute :pspReference, :psp_reference
  alias_attribute :merchantReference, :merchant_reference
  alias_attribute :skinCode, :skin_code
  alias_attribute :merchantSig, :merchant_sig
  alias_attribute :paymentMethod, :payment_method
  alias_attribute :shopperLocale, :shopper_locale
  alias_attribute :merchantReturnData, :merchant_return_data

  belongs_to :order, class_name: 'Spree::Order',
    primary_key: :number,
    foreign_key: :merchant_reference

  has_one :payment, class_name: 'Spree::Payment', as: :source

  # OPTIMIZE this is inefficient and does N queries + 1
  has_many :notifications,
    -> { includes :prev, :next },
    class_name: 'AdyenNotification',
    foreign_key: :merchant_reference,
    primary_key: :merchant_reference

  # these should really just be informed by the auth response, but it's likely
  # this will always be the case - it will error if it doesn't succeed
  def actions
    [:capture, :void, :refund]
  end

  def can_capture?
    last_message_was { |x| x.authorisation? }
  end

  def can_void?
    last_message_was { |x| x.authorisation? }
  end

  def can_refund?
    last_message_was { |x| x.capture? }
  end

  private
  def last_message_was &block
    AdyenNotification.
      most_recent(notifications).
      try!(&block) || false
  end
end
