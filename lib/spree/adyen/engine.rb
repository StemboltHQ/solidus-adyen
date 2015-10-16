module Spree
  module Adyen
    class Engine < ::Rails::Engine
      engine_name "solidus-adyen"

      isolate_namespace Spree::Adyen

      config.autoload_paths += Dir["#{config.root}/lib/**/"]

      config.generators do |g|
        g.test_framework :rspec
      end

      initializer "spree.solidus-adyen.payment_methods", :after => "spree.register.payment_methods" do |app|
        app.config.spree.payment_methods << Gateway::AdyenPayment
        app.config.spree.payment_methods << Gateway::AdyenHPP
        app.config.spree.payment_methods << Gateway::AdyenPaymentEncrypted
      end

      initializer "solidus-adyen.assets.precompile", :group => :all do |app|
        app.config.assets.precompile += %w[
          adyen.encrypt.js
        ]
      end
    end
  end
end
