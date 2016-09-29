FactoryGirl.define do
  factory :spree_adyen_ratepay_source, aliases: [:ratepay_source], class: "Spree::Adyen::RatepaySource" do
    auth_result "Authorised"
    psp_reference { SecureRandom.hex }
    dob_day "12"
    dob_month "12"
    dob_year "1970"
  end
end
