require 'spec_helper'

RSpec.describe AdyenNotification do
  it { is_expected.to have_many(:next).inverse_of(:prev) }
  it { is_expected.to belong_to(:prev).inverse_of(:next) }
  it { is_expected.to belong_to :order }

  describe "#build" do
    subject { described_class.build params }

    let(:params) do
      { "currency" => "USD",
        "eventCode" => "AUTHORISATION",
        "eventDate" => "2013-10-21T00:00:00.00Z",
        "live" => "false",
        "merchantAccountCode" => "Test",
        "merchantReference" => "R999999999",
        "operations" => "CANCEL,CAPTURE,REFUND",
        "originalReference" => "",
        "paymentMethod" => "visa",
        "pspReference" => "999999999",
        "reason" => "41061:1111:6/2016",
        "success" => "true",
        "value" => "6999",
      }
    end

    it "makes a new notification with the expected fields" do
      is_expected.
        to be_a_new_record.
        and have_attributes(
          currency: "USD",
          event_code: "AUTHORISATION",
          event_date: Time.utc(2013, 10, 21),
          live: false,
          merchant_account_code: "Test",
          merchant_reference: "R999999999",
          operations: "CANCEL,CAPTURE,REFUND",
          original_reference: "",
          payment_method: "visa",
          psp_reference: "999999999",
          reason: "41061:1111:6/2016",
          success: true,
          value: 6999,
        )
    end
  end
end
