FactoryGirl.define do
  factory :spree_gateway_adyen_hpp, aliases: [:hpp_gateway],
    class: 'Spree::Gateway::AdyenHPP' do
    name "Adyen"
    environment 'test'
    preferences(
      skin_code: 'XXXXX',
      shared_secret: '1234',
      merchant_account: 'XXXX')
  end
end
