FactoryGirl.define do
  factory :spree_gateway_adyen_credit_card,
          aliases: [:adyen_cc_gateway],
          class: "Spree::Gateway::AdyenCreditCard" do
    name "Adyen Credit Card"
  end
end
