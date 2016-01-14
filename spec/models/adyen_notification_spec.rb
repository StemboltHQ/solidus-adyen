require "spec_helper"

RSpec.describe AdyenNotification do
  it { is_expected.to have_many(:next).inverse_of(:prev) }
  it { is_expected.to belong_to(:prev).inverse_of(:next) }
  it { is_expected.to belong_to :order }

  describe ".payment" do
    subject { notification.payment }

    let(:ref) { "999999999" }
    let!(:payment) { create :payment, response_code: ref }
    let!(:notification) { described_class.new attr => ref }

    shared_examples "finds the payment" do
      it { is_expected.to eq payment }
    end

    context "normal notification" do
      let(:attr) { :original_reference }
      include_examples "finds the payment"
    end

    context "modification notification" do
      let(:attr) { :psp_reference }
      include_examples "finds the payment"
    end

    context "payment with no reference" do
      let!(:payment) { create :payment, response_code: nil }

      context "normal notification" do
        let!(:notification) {
          described_class.new :merchant_reference => payment.order.number
        }
        include_examples "finds the payment"
      end
    end

    context "no connected order" do
      let!(:notification) {
        described_class.new :merchant_reference => "notarealorder"
      }
      it { is_expected.to eq nil }
    end
  end

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
          original_reference: nil,
          payment_method: "visa",
          psp_reference: "999999999",
          reason: "41061:1111:6/2016",
          success: true,
          value: 6999,
        )
    end
  end

  describe ".actions" do
    subject { notification.actions }
    let(:notification) { create :notification, :auth, operations: operations }

    context "when the notification has operations" do
      let(:operations) { "CAPTURE,REFUND,CANCEL_OR_REFUND" }

      it { is_expected.to eq ["capture", "refund", "cancel_or_refund"] }
    end

    context "when the notification's operations are nil" do
      let(:operations) { nil }
      it { is_expected.to eq [] }
    end
  end
end
