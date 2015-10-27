FactoryGirl.define do
  factory :hpp_payment, parent: :payment do
    association :payment_method, factory: :hpp_gateway
    association :source, factory: :hpp_source
    order
  end

  factory :bogus_hpp_payment, parent: :payment do
    association :payment_method, factory: :bogus_hpp_gateway
    association :source, factory: :hpp_source
    order

    before :create do |record, evaluator|
      # these associations/keys are awful and are making this difficult
      record.source.order = record.order
      record.source.merchant_reference = record.order.number
    end
  end
end
