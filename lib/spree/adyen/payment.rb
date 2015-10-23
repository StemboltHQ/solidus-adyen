# Because adyen payment modifications are delayed we don't actually know if
# the request succeeded after doing it. For that reason we can't use the
# standard capture! and friends as they change the payment state and would
# result is false positives (payment could fail after capture).
module Spree::Adyen::Payment
  def adyen_hpp_capture!
    started_processing!
    # success state must remain as processing, it will change to completed
    # once the notification is received
    gateway_action(source, :capture, :started_processing)
  end

  def adyen_hpp_refund!
    raise NotImplementedError
  end

  def adyen_hpp_cancel!
    raise NotImplementedError
  end
end
