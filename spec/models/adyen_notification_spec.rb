require 'spec_helper'

RSpec.describe AdyenNotification do
  it { is_expected.to have_one(:next).inverse_of(:prev) }
  it { is_expected.to belong_to(:prev).inverse_of(:next) }

  describe "#log" do
    let(:psp_reference) { "8513823667306210" }
    let!(:payment) { create(:payment, response_code: psp_reference) }
    let(:params) do
      { "pspReference" => psp_reference,
        success: success,
        "eventDate"=>"2013-10-21T14:45:45.93Z",
        "merchantAccountCode"=>"Test",
        "reason"=>"41061:1111:6/2016",
        "originalReference" => "",
        "value"=>"6999",
        "eventCode"=>"AUTHORISATION",
        "merchantReference"=>"R354361834-A3JC8TNJ",
        "operations"=>"CANCEL,CAPTURE,REFUND",
        "paymentMethod"=>"visa",
        "currency"=>"USD",
        "live"=>"false" }
    end

    context "payement was not authorized" do
      let(:success) { false }
      let(:notification) { subject.class.log(params) }

      it "invalidates payment" do
        expect(payment.reload).not_to be_invalid

        notification.handle!
        expect(payment.reload).to be_invalid
      end
    end

    context "payemnt was successful" do
      let(:success) { true }
      let(:notification) { subject.class.log(params) }

      it "doesnt invalidate payment" do
        notification.handle!
        expect(payment.reload).not_to be_invalid
      end
    end
  end

  describe ".most_recent" do
    let(:auth)    { create :adyen_notification, :auth }
    let(:capture) { create :adyen_notification, :capture, prev: auth }
    let(:refund)  { create :adyen_notification, :refund, prev: capture }
    let!(:notifications) { [auth, capture, refund] }

    it "returns the most recent notification in the message chain" do
      expect(notifications).to all satisfy{ |x| x.most_recent == refund }
    end
  end
end
