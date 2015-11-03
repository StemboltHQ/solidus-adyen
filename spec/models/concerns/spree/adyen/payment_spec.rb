require "spec_helper"

describe Spree::Adyen::Payment do
  let(:payment) { create :hpp_payment }

  shared_examples "gateway action" do
    context "when the action succeeds" do
      include_context "mock adyen api", success: true

      it "logs the response" do
        expect{ subject }.to change{ payment.reload.log_entries.count }.by(1)
      end

      it "changes payment state to processing" do
        expect{ subject }.to change{ payment.state }.to("processing")
      end
    end

    context "when the action fails" do
      include_context(
        "mock adyen api",
        success: false,
        fault_message: "Expected message")

      it "logs the response" do
        expect{ subject }.
          to raise_error(Spree::Core::GatewayError).
          and change{ payment.reload.log_entries.count }.by(1)
      end

      it "does not change the status of the payment" do
        expect{ subject }.
          to raise_error(Spree::Core::GatewayError, "Expected message").
          and keep { payment.reload.state }
      end
    end
  end

  describe "cancel!" do
    subject { payment.cancel! }
    include_examples "gateway action"

    context "when the payment doesn't have an hpp source" do
      let(:payment) { create :payment }

      it "keeps the orginal behaviour" do
        expect{ subject }.
          to change { payment.reload.state }.
          from("checkout").
          to("void")
      end
    end
  end

  describe "capture!" do
    subject { payment.capture! }
    include_examples "gateway action"

    context "when the payment doesn't have an hpp source" do
      let(:payment) { create :payment }

      it "keeps the orginal behaviour" do
        expect{ subject }.
          to change { payment.reload.state }.
          from("checkout").
          to("completed").

          and change { payment.capture_events.count }.
          by(1)
      end
    end
  end

  describe "credit!" do
    subject { payment.credit! "1000", currency: "EUR" }
    include_examples "gateway action"
  end
end
