FactoryGirl.define do
  factory :spree_adyen_hpp_source, aliases: [:hpp_source], class: "Spree::Adyen::HppSource" do
    skin_code "XXXXXXXX"
    shopper_locale "en_GB"
    auth_result "AUTHORISED"
    psp_reference { SecureRandom.hex }
    merchant_sig "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    payment_method "amex"
    order

    trait :sofort do
      payment_method "directEbanking"
    end
  end
end
