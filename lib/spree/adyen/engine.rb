module Spree
  module Adyen
    class Engine < ::Rails::Engine
      engine_name "solidus-adyen"

      isolate_namespace Spree::Adyen

      config.autoload_paths += Dir["#{config.root}/lib/**/"]

      config.autoload_paths += %W(
        #{config.root}/app/controllers/concerns
        #{config.root}/app/models/concerns
      )

      config.generators do |g|
        g.test_framework :rspec
      end

      initializer "spree.solidus-adyen.payment_methods", after: "spree.register.payment_methods" do |app|
        app.config.spree.payment_methods << Gateway::AdyenHPP
        app.config.spree.payment_methods << Gateway::AdyenCreditCard
      end

      def self.activate
        Spree::Payment.include Spree::Adyen::Payment
        Spree::Order.include Spree::Adyen::Order
        Spree::Admin::RefundsController.include Spree::Adyen::Admin::RefundsController
      end

      config.to_prepare(&method(:activate).to_proc)
    end
  end
end
