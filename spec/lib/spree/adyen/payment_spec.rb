require "spec_helper"

describe Spree::Adyen::Payment do
  let(:payment) { create :payment }

  shared_examples "gateway action" do |action|
    let(:am_response) { create :am_response, :success }

    before do
      expect(payment.payment_method).to receive(action).
        and_return(am_response)
    end

    it "logs the response" do
      expect{ subject }.to change{ payment.log_entries.count }.by(1)
    end

    it "changes payment state to processing" do
      expect{ subject }.to change{ payment.state }.to("processing")
    end

    context "when the capture dispatch fails" do
      let(:am_response) do
        create :am_response, :failure, message: "Expected message"
      end

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
    include_examples "gateway action", :cancel
  end

  describe "adyen_hpp_capture!" do
    subject { payment.adyen_hpp_capture! }

    let(:payment) { create :payment }
    include_examples "gateway action", :capture
  end
end
