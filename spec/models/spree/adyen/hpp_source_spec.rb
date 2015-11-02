require "spec_helper"

RSpec.describe Spree::Adyen::HppSource do
  include_context "mock adyen api", success: true

  it { is_expected.to belong_to(:order) }
  it { is_expected.to have_one(:payment) }
  it { is_expected.to have_many(:notifications) }

  let(:hpp_source) do
    create :hpp_source,
      psp_reference: "999999999",
      merchant_reference: "R11111111",
      payment: create(:hpp_payment)
  end

  describe ".actions" do
    subject { hpp_source.actions }
    let!(:notification) do
      create(
        :notification,
        :auth,
        operations: "CAPTURE,REFUND",
        psp_reference: "999999999",
        merchant_reference: "R11111111",
        processed: true
      )
    end

    it { expect(hpp_source.notifications.count).to eq 1 }
    it { expect(hpp_source.actions).
         to eq %w{adyen_hpp_capture credit} }

    shared_examples "has no actions" do
      it { is_expected.to eq [] }
    end

    context "when it has no auth notification" do
      let!(:notification) { nil }
      include_examples "has no actions"
    end

    context "when the payment is void" do
      before { hpp_source.payment.void }
      include_examples "has no actions"
    end

    context "when the payment is still proccesing" do
      before { hpp_source.payment.started_processing! }
      include_examples "has no actions"
    end
  end

  describe ".can_adyen_hpp_capture?" do
    subject { hpp_source.can_adyen_hpp_capture? payment }
    let!(:payment) { create :payment, amount: 10.0 }

    it { is_expected.to be true }

    context "when there is no outstanding balance" do
      before do
        payment.
          capture_events.
          create! amount: ::Money.new(1000, "EUR").to_f
      end
      it { is_expected.to be false }
    end
  end

  describe ".authorised?" do
    subject { described_class.new(auth_result: event).authorised? }

    context "when pending" do
      let(:event) { "PENDING" }
      it { is_expected.to be true }
    end

    context "when authorised" do
      let(:event) { "AUTHORISED" }
      it { is_expected.to be true }
    end

    context "when something else" do
      let(:event) { "REFUSED" }
      it { is_expected.to be false }
    end
  end

  describe ".can_adyen_hpp_cancel?" do
    subject { hpp_source.can_adyen_hpp_cancel? hpp_source.payment }

    context "when the payment has refunds" do
      before { create :refund, amount: 1, payment: hpp_source.payment }
      it { is_expected.to be false }
    end

    context "when the payment doesn't have refunds" do
      it { is_expected.to be true }
    end
  end
end
