module Spree
  class Gateway::AdyenCreditCard < Gateway
    class ClearTextCardNumberError < StandardError; end

    include Spree::Gateway::AdyenGateway
    preference :cse_library_location, :string

    def cse_library_location
      ENV["ADYEN_CSE_LIBRARY_LOCATION"] || preferred_cse_library_location
    end

    def method_type
      "adyen_encrypted_cc"
    end

    # We need to authorize Adyen credit card payments in the payment step
    # during checkout when we still have the encrypted card data. Since the
    # payment should already be authorized here, we return a dummy response.
    def authorize(amount, card, gateway_options)
      ActiveMerchant::Billing::Response.new(true, "dummy authorization response")
    end
  end
end
