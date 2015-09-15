require 'spec_helper'

RSpec.describe AdyenNotification do
  it { is_expected.to have_one(:next).inverse_of(:prev) }
  it { is_expected.to belong_to(:prev).inverse_of(:next) }
  it { is_expected.to belong_to :order }

  describe "#log" do
    let(:psp_reference) { "8513823667306210" }
    let!(:payment) { create(:payment, response_code: psp_reference) }
    let!(:order) { create :order }
    let(:params) do
      { "pspReference" => psp_reference,
        success: success,
        "merchantReference"=> order.number,
        "eventDate"=>"2013-10-21T14:45:45.93Z",
        "merchantAccountCode"=>"Test",
        "reason"=>"41061:1111:6/2016",
        "originalReference" => "",
        "value"=>"6999",
        "eventCode"=>"AUTHORISATION",
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

  describe "#most_recent" do
    subject { described_class.most_recent notifications }
    let(:order) { create :order }
    let!(:notifications) { [auth, capture, refund] }
    let(:auth) { create :notification, :auth, order: order}
    let(:capture) { create :notification, :capture, order: order, prev: auth }
    let(:refund) { create :notification, :refund, order: order, prev: capture }

    it "returns the most recent notification in the message chain" do
      is_expected.to eq refund
    end
  end
end
