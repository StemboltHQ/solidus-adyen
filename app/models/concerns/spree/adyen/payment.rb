# Because adyen payment modifications are delayed we don't actually know if
# the request succeeded after doing it. For that reason we can't use the
# standard capture! and friends as they change the payment state and would
# result is false positives (payment could fail after capture).
module Spree::Adyen::Payment
  extend ActiveSupport::Concern

  # adyen_hpp_capture! :: bool | error
  def adyen_hpp_capture!
    amount = money.money.cents
    process do
      payment_method.send(:capture, amount, response_code, gateway_options)
    end
  end

  # adyen_hpp_credit! :: bool | error
  #
  # Issue a request to credit the payment, this does NOT perform validation on
  # the amount to be credited, which is assumed to have been done prior to this.
  def adyen_hpp_credit! amount, options
    process { payment_method.credit(amount, response_code, options) }
  end

  # adyen_hpp_cancel! :: bool | error
  #
  # Borrowed from handle_void_response, this has been modified so that it won't
  # actually void the payment _yet_.
  def adyen_hpp_cancel!
    process { payment_method.cancel response_code }
  end

  private

  def process &block
    check_environment
    response = nil

    Spree::Payment.transaction do
      protect_from_connection_error do
        started_processing!
        response = yield(block)
        raise ActiveRecord::Rollback unless response.success?
      end
    end

    record_response(response)

    if response.success?
      # The payments controller's fire action expects a truthy value to
      # indicate success
      true
    else
      # this is done to be consistent with capture, but we might actually
      # want them to just return to the previous state
      gateway_error(response)
    end
  end
end
