# Because adyen payment modifications are delayed we don't actually know if
# the request succeeded after doing it. For that reason we can't use the
# standard capture! and friends as they change the payment state and would
# result is false positives (payment could fail after capture).
module Spree::Adyen::Payment
  # adyen_hpp_capture! :: bool | error
  def adyen_hpp_capture!
    started_processing!
    # success state must remain as processing, it will change to completed
    # once the notification is received
    gateway_action(response_code, :capture, :started_processing)
  end

  # adyen_hpp_refund! :: bool | error
  def adyen_hpp_refund!
    raise NotImplementedError
  end

  # adyen_hpp_cancel! :: bool | error
  #
  # Borrowed from handle_void_response, this has been modified so that it won't
  # actually void the payment _yet_.
  def adyen_hpp_cancel!
    started_processing!

    response = payment_method.cancel response_code
    record_response(response)

    if response.success?
      # The payments controller's fire action expects a truthy value to
      # indicate success
      true
    else
      # this is done to be consistent with capture, but we might actually
      # want them to just return to the previous state
      self.failure
      gateway_error(response)
    end
  end
end
