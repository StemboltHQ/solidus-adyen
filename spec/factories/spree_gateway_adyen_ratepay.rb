FactoryBot.define do
  factory :spree_gateway_adyen_ratepay, aliases: [:ratepay_gateway],
    class: "Spree::Gateway::AdyenRatepay" do
    name "Ratepay"

    trait :env_configured do
      preferred_api_password { ENV.fetch("ADYEN_API_PASSWORD") }
      preferred_api_username { ENV.fetch("ADYEN_API_USERNAME") }
    end
  end
end
