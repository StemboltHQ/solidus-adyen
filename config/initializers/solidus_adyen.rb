Rails.application.config.assets.precompile += %w(
  spree/checkout/payment/adyen.js
  spree/checkout/payment/adyen_encrypted_credit_card.js
)

Rails.application.config.assets.precompile += %w(
  test-adyen-encrypt.js
) if Rails.env.test?
