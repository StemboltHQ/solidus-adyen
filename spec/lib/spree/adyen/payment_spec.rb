require "spec_helper"

describe Spree::Adyen::Payment do
  let(:payment) { create :hpp_payment }

  shared_examples "gateway action" do
    context "when the action succeeds" do
      include_context "mock adyen api", success: true

      it "logs the response" do
        expect{ subject }.to change{ payment.log_entries.count }.by(1)
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

      it "changes payment state to failed" do
        expect{ subject }.
          to change{ payment.state }.to("failed").

          and raise_error(
            Spree::Core::GatewayError, "Expected message")
      end
    end
  end

  describe "adyen_hpp_cancel!" do
    subject { payment.adyen_hpp_cancel! }
    include_examples "gateway action"
  end

  describe "adyen_hpp_capture!" do
    subject { payment.adyen_hpp_capture! }
    include_examples "gateway action"
  end

  describe "adyen_hpp_credit!" do
    subject { payment.adyen_hpp_credit! "1000", currency: "EUR" }
    include_examples "gateway action"
  end
end
