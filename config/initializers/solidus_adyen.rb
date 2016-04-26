Rails.application.config.assets.precompile += %w( spree/checkout/payment/adyen.js spree/checkout/payment/adyen_encrypted_credit_card.js)

Spree::Adyen::HPP.configure do |config|
  config.params_class = Spree::Adyen::HPP::Params
end
