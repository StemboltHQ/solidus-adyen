# This models the response that is received after a user is redirected from the
# Adyen Hosted Payment Pages. It's used as the the source for the Spree::Payment
# and keeps track of the messages received from the notifications end point.
#
# Attributes defined are dervived from the docs:
# https://docs.adyen.com/display/TD/HPP+payment+response
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

  has_one :payment, class_name: 'Spree::Payment', as: :source
end
