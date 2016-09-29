module Spree
  class Gateway::AdyenRatepay < Spree::Gateway
    include Spree::Gateway::AdyenGateway

    def method_type
      "adyen_ratepay"
    end

    def payment_source_class
      Adyen::RatepaySource
    end

    def authorize(amount, source, gateway_options)
      # We need to authorise Ratepay payments on the `payment` checkout step,
      # so that we don't need to persist the user's date of birth. Once we hit
      # this the payment should already be authorized.
      ActiveMerchant::Billing::Response.new(true, "successful Ratepay authorization")
    end
  end
end
