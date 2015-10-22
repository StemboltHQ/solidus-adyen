require 'spec_helper'

RSpec.describe Spree::Adyen::NotificationProcessing do
  describe "#find_payment" do
    subject { described_class.find_payment notification }

    let!(:payment) { create :payment, response_code: reference }

    let(:reference) { "111111111" }

    shared_examples "finds the payment" do
      it "finds the payment" do
        is_expected.to eq payment
      end
    end

    context "when it is a normal event" do
      let!(:notification) do
        create(:notification, :auth, psp_reference: reference)
      end

      include_examples "finds the payment"
    end

    context "when it is a modification event" do
      let!(:notification) do
        create(
          :notification,
          :capture,
          original_reference: reference,
          psp_reference: "111111112"
        )
      end

      include_examples "finds the payment"
    end
  end

  describe "#process/2" do
    subject { described_class.process(notification, payment)}

    let!(:payment) do
      create(:payment, state: payment_state, payment_method: hpp_gateway)
    end

    let!(:hpp_gateway) do
      create(:hpp_gateway, auto_capture: auto_capture)
    end

    let!(:notification) do
      create(
        :notification,
        event_type, # these are registered traits, refer to the factory
        success: success,
        value: 2399,
        currency: "EUR"
      )
    end

    let(:payment_state) { "pending" }
    let(:auto_capture) { false }
    let(:success) { true }

    shared_examples "completes payment" do
      it "updates the captured amount" do
        expect{ subject }.
          to change{ payment.captured_amount }.
          from(0).
          to(23.99).

          and change{ payment.capture_events.count }.
          from(0).
          to(1)
      end

      it "completes the payment" do
        expect{ subject }.
          to change{ payment.state }.
          from("pending").
          to("completed")
      end
    end

    shared_examples "fails payment" do
      it "marks the payment as a failure" do
        expect{ subject }.
          to change{ payment.state }.
          from("pending").
          to("failed")
      end
    end

    shared_examples "does nothing" do
      it "does not change the payment state" do
        expect{ subject }.to_not change{ payment.state }
      end

      it "does not change the captured amount" do
        expect{ subject }.to_not change{ payment.captured_amount }
      end
    end

    context "when event is AUTHORISATION" do
      let(:event_type) { :auth }

      it "changes the available actions"

      context "and payment method was c_cash", pending: true do
        pending "completes payment"
      end

      context "and payment method was bank transfer", pending: true do
        pending "completes payment"
      end

      context "and payment method was ideal" do
        let(:event_type) { :ideal_auth }
        include_examples "completes payment"
      end

      context "and auto-capture is enabled" do
        let(:auto_capture) { true }
        include_examples "completes payment"
      end

      context "and it was not successful" do
        let(:success) { false }
        include_examples "fails payment"

        context "and the payment was already complete" do
          let(:payment_state) { "completed" }
          include_examples "does nothing"
        end
      end
    end

    context "when event is CAPTURE" do
      let(:event_type) { :capture }
      include_examples "completes payment"
    end
  end
end
