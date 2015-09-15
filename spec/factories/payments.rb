FactoryGirl.define do
  factory :hpp_payment, parent: :payment do
    association :payment_method, factory: :hpp_gateway
    association :source, factory: :hpp_source
    order
  end
end
