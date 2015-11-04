# Because adyen payment modifications are delayed we don't actually know if
# the request succeeded after doing it. For that reason we can't use the
# standard capture! and friends as they change the payment state and would
# result is false positives (payment could fail after capture).
module Spree::Adyen::Payment
  extend ActiveSupport::Concern
  include Spree::Adyen::HppCheck

  # capture! :: bool | error
  def capture!
    if hpp_payment?
      amount = money.money.cents
      process do
        payment_method.send(:capture, amount, response_code, gateway_options)
      end
    else
      super
    end
  end

  # credit! :: bool | error
  #
  # Issue a request to credit the payment, this does NOT perform validation on
  # the amount to be credited, which is assumed to have been done prior to this.
  #
  # credit! is only implemented for hpp payments, because of the delayed manner
  # of Adyen api communications. If this method is called on a payment that is
  # not from Adyen then it should fail. This is crummy way of getting around the
  # fact that Payment methods cannot specifiy these methods.
  def credit! amount, options
    if hpp_payment?
      process { payment_method.credit(amount, response_code, options) }
    else
      fail NotImplementedError, "Spree::Payment does not implement credit!"
    end
  end

  # cancel! :: bool | error
  #
  # Borrowed from handle_void_response, this has been modified so that it won't
  # actually void the payment _yet_.
  def cancel!
    if hpp_payment?
      if source.requires_manual_refund?
        log_manual_refund
      else
        process { payment_method.cancel response_code }
      end
    else
      super
    end
  end

  private

  def log_manual_refund
    message = I18n.t("solidus-adyen.manual_refund.log_message")
    record_response(
      OpenStruct.new(
        success?: false,
        message: message))
  end

  def process &block
    check_environment
    response = nil

    Spree::Payment.transaction do
      protect_from_connection_error do
        started_processing!
        response = yield(block)
        fail ActiveRecord::Rollback unless response.success?
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
