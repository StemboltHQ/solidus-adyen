# This gateway is only available in test environments. It is **not** intended
# for use via the spree back end, for that use BogusSimple.
#
# This is an even simpler version of BogusSimple, where all it does is respond
# based on the success preference.
#
# It's suggested use is via the factory, via
#   `create :bogus_hpp_gateway, (:forced_success|:forced_failure)`
#
class Spree::Gateway::AdyenHPPBogus < Spree::Gateway::AdyenHPP
  preference :success, :bool, default: true

  def method_type
    "Adyen Bogus"
  end

  def environment
    "test"
  end

  def provider
    raise "Adyen Hpp Bogus has no provider"
  end

  def authorize(amount, source, gateway_options)
    FactoryGirl.create :active_merchant_billing_response,
      success: preferred_success
  end

  def capture(amount, response_code, _options)
    FactoryGirl.create :active_merchant_billing_response,
      success: preferred_success,
      options: { authorization: response_code }
  end

  def void(response_code, gateway_options = {})
    raise NotImplementedError
  end

  def credit(credit_cents, transaction_id, gateway_options = {})
    raise NotImplementedError
  end
end
