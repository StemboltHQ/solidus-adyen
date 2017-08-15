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
        app.config.spree.payment_methods << Gateway::AdyenRatepay
        Spree::PermittedAttributes.source_attributes << :adyen_token
        Spree::PermittedAttributes.source_attributes << :dob_day
        Spree::PermittedAttributes.source_attributes << :dob_month
        Spree::PermittedAttributes.source_attributes << :dob_year
        Spree::PermittedAttributes.source_attributes << :device_token
      end

      # The Adyen gem doesn't provide a way to pass the shopper's billing
      # address with payment requests, which is used for AVS checks.
      # The PaymentService module included below provides that functionality.
      #
      # This is going to be PR'ed to Adyen and should be deleted if it gets merged.
      def self.activate
        Spree::CheckoutController.include Spree::Adyen::CheckoutController
        Spree::CreditCard.prepend Spree::CreditCard::AdyenToken
        Spree::Payment.include Spree::Adyen::Payment
        Spree::Order.include Spree::Adyen::Order
        Spree::Admin::RefundsController.include Spree::Adyen::Admin::RefundsController
        ::Adyen::API::PaymentService.include Spree::Adyen::PaymentService
        ::Adyen::REST::Response.include Spree::Adyen::REST::Response
        ::Adyen::REST::AuthorisePayment::Response.include Spree::Adyen::REST::AuthorisePaymentResponse
        ::Adyen::REST::ModifyPayment::Response.include Spree::Adyen::REST::ModifyPaymentResponse
      end

      config.to_prepare(&method(:activate).to_proc)
    end
  end
end
