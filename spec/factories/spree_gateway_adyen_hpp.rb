FactoryGirl.define do
  factory :spree_gateway_adyen_hpp, aliases: [:hpp_gateway],
    class: 'Spree::Gateway::AdyenHPP' do
    name "Adyen"
    environment 'test'
  end
end
