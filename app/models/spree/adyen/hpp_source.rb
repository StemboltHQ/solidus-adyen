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

  # FIXME should change this to find the auth notification by order number, then
  # all notification that have a original ref that matches it's psp
  has_many :notifications,
    class_name: 'AdyenNotification',
    foreign_key: :merchant_reference,
    primary_key: :merchant_reference


  # these should really just be informed by the auth response, but it's likely
  # this will always be the case - it will error if it doesn't succeed
  def actions
    ['capture', 'void', 'credit']
  end

  def can_capture? payment
    can_void? payment
  end

  def can_void? payment
    authorised? && !captured?
  end

  def can_credit? payment
    captured?
  end

  private
  def captured?
    self.notifications.any? { |x| x.capture? }
  end

  def authorised?
    self.notifications.any? { |x| x.authorisation? }
  end
end
