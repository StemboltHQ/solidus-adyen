Rails.application.config.assets.precompile += %w( spree/checkout/payment/adyen.js )

Spree::Adyen::HPP.configure do |config|
  config.params_class = Spree::Adyen::HPP::Params
end
