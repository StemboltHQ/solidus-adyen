# https://docs.adyen.com/display/TD/Notification+fields
FactoryGirl.define do
  factory :adyen_notification do
     live false
     #event_code "AUTHORISATION"
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

     trait :auth do
       event_code "AUTHORISATION"
       operations "CANCEL CAPTURE REFUND"
       reason "31893:0002:8/2018"
     end

     trait :capture do
       event_code "CAPTURE"
     end

     trait :refund do
       event_code "REFUND"
     end
  end
end
