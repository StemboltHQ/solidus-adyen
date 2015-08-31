module Spree
  class AdyenPaymentCancellationResponse < SimpleDelegator
    attr_reader :authorization

    def initialize(adyen_cancel_payment_response, response_code)
      super(adyen_cancel_payment_response)
      @authorization = response_code
    end

  end
end
