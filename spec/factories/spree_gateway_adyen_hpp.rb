FactoryGirl.define do
  factory :spree_gateway_adyen_hpp, aliases: [:hpp_gateway],
    class: "Spree::Gateway::AdyenHPP" do
    name "Adyen"
    environment "test"
    preferences(
      skin_code: "XXXXX",
      shared_secret: "1234",
      merchant_account: "XXXX",
      days_to_ship: 3
    )

    trait :env_configured do
      preferred_test_mode true
      preferred_days_to_ship 1
      preferred_api_password { ENV.fetch("ADYEN_API_PASSWORD") }
      preferred_api_username { ENV.fetch("ADYEN_API_USERNAME") }
      preferred_merchant_account { ENV.fetch("ADYEN_MERCHANT_ACCOUNT") }
      preferred_shared_secret { ENV.fetch("ADYEN_SHARED_SECRET") }
      preferred_skin_code { ENV.fetch("ADYEN_SKIN_CODE") }
    end
  end
end
