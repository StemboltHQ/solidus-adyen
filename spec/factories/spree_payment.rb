FactoryBot.define do
  factory :hpp_payment, parent: :payment do
    association :payment_method, factory: :hpp_gateway
    association :source, factory: :hpp_source
    order

    before :create do |record, _|
      # these associations/keys are awful and are making this difficult
      record.response_code = record.source.psp_reference
      record.source.order = record.order
      record.source.merchant_reference = record.order.number
    end
  end

  factory :ratepay_payment, parent: :payment do
    association :payment_method, factory: :ratepay_gateway
    association :source, factory: :ratepay_source
  end

  factory :adyen_cc_payment, parent: :payment do
    association :payment_method, factory: :spree_gateway_adyen_credit_card
    association :source, factory: :credit_card
  end
end
