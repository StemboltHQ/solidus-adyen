FactoryGirl.define do
  factory(
    :spree_gateway_adyen_hpp_bogus,
    aliases: ["bogus_hpp_gateway"],
    class: "Spree::Gateway::AdyenHPPBogus"
  ) do

    name "Bogus Adyen HPP Gateway"
    preferred_success true
    environment "test"
    preferences(
      skin_code: 'XXXXX',
      shared_secret: '1234',
      merchant_account: 'XXXX',
      days_to_ship: 3
    )

    trait :forced_success do
      preferred_success true
    end

    trait :forced_failure do
      preferred_success false
    end
  end
end
