module Spree
  # Gateway for Adyen Hosted Payment Pages solution
  class Gateway::AdyenHPP < Gateway
    include Spree::Gateway::AdyenGateway

    preference :skin_code, :string
    preference :shared_secret, :string
    preference :days_to_ship, :integer, default: 1
    preference :restricted_brand_codes, :string, default: ''

    def method_type
      "adyen"
    end

    def shared_secret
      ENV["ADYEN_SHARED_SECRET"] || preferred_shared_secret
    end

    def skin_code
      ENV["ADYEN_SKIN_CODE"] || preferred_skin_code
    end

    def ship_before_date
      preferred_days_to_ship.days.from_now
    end

    def authorize(amount, source, gateway_options)
      # to get around the order checking for processed payments we create payments
      # in the checkout state and allow the payment method to attempt to auth
      # them here. We just return a dummy response here because the payment has
      # already been authorized
      ActiveMerchant::Billing::Response.new(true, "successful hpp payment")
    end

    def restricted_brand_codes
      preferred_restricted_brand_codes.split(',').compact.uniq
    end
  end
end
