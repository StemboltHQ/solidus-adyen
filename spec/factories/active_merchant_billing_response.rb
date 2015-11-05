FactoryGirl.define do
  factory(
    :active_merchant_billing_response,
    aliases: ["am_response"],
    class: "ActiveMerchant::Billing::Response"
  ) do
    skip_create
    params Hash.new
    options Hash.new
    message ""

    initialize_with { new(success, message, params, options) }

    trait :success do
      success true
    end

    trait :failure do
      success false
      message "This is an expected failure"
    end
  end
end
