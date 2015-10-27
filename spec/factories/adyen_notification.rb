# https://docs.adyen.com/display/TD/Notification+fields
FactoryGirl.define do
  factory :adyen_notification, aliases: [:notification] do
     live false
     psp_reference { SecureRandom.hex }
     original_reference nil
     merchant_reference "R000000000"
     merchant_account_code "MyMerchantAccount"
     event_date 30.seconds.ago
     success true
     payment_method "amex"
     operations ""
     currency "USD"
     value 2599
     reason ""
     processed false
     created_at DateTime.now
     updated_at DateTime.now

     transient do
       payment nil
     end

     before(:create) do |record, evaluator|
       if evaluator.payment
         record.merchant_reference = evaluator.payment.order.number
       end
     end

     trait :normal_event do
       before(:create) do |record, evaluator|
         if evaluator.payment
           record.psp_reference = evaluator.payment.response_code
         end
       end
     end

     trait :modification_event do
       before(:create) do |record, evaluator|
         if evaluator.payment
           record.original_reference = evaluator.payment.response_code
         end
       end
     end

     trait :auth do
       normal_event
       event_code "AUTHORISATION"
       operations "CANCEL,CAPTURE,REFUND"
       reason "31893:0002:8/2018"
     end

     trait :bank_auth do
       auth
       operations "REFUND"
     end

     trait :ideal_auth do
       bank_auth
       payment_method "ideal"
     end

     trait :capture do
       modification_event
       event_code "CAPTURE"
     end

     trait :cancel_or_refund do
       modification_event
       event_code "CANCEL_OR_REFUND"
     end

     trait :refund do
       modification_event
       event_code "REFUND"
     end

     trait :pending do
       normal_event
       event_code "PENDING"
     end
  end
end
