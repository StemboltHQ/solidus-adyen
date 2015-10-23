# Because adyen payment modifications are delayed we don't actually know if
# the request succeeded after doing it. For that reason we can't use the
# standard capture! and friends as they change the payment state and would
# result is false positives (payment could fail after capture).
module Spree::Adyen::Payment
  def adyen_hpp_capture!
    # essentially one half of Spree::Payment#capture!
    # other half happens in the notification processing
    amount ||= money.money.cents
    started_processing!

    response = payment_method.capture(
      amount,
      response_code,
      gateway_options
    )

    record_response(response)
  end

  def adyen_hpp_refund!
    raise NotImplementedError
  end

  def adyen_hpp_cancel!
    raise NotImplementedError
  end
end
