require 'spec_helper'

RSpec.describe Spree::Adyen::NotificationProcessor do
  describe "#process" do
    subject { described_class.new(notification).process! }

    let!(:payment) do
      create(:payment, state: payment_state, payment_method: hpp_gateway)
    end

    let!(:hpp_gateway) do
      create(:bogus_hpp_gateway)
    end

    let!(:notification) do
      create(
        :notification,
        event_type, # these are registered traits, refer to the factory
        success: success,
        value: 2399,
        currency: "EUR",
        payment: payment
      )
    end

    let(:payment_state) { "pending" }
    let(:success) { true }

    shared_examples "returns the notification" do
      it "always returns the notification" do
        is_expected.to be_a AdyenNotification
      end
    end

    shared_examples "processed event" do
      include_examples "returns the notification"

      it "marks the notification as processed" do
        expect{ subject }.
          to change{ notification.processed }.
          from(false).
          to(true)
      end
    end

    shared_examples "completes payment" do
      include_examples "processed event"

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
          to change{ payment.reload.state }.
          from("pending").
          to("completed")
      end
    end

    shared_examples "fails payment" do
      include_examples "processed event"

      it "marks the payment as a failure" do
        expect{ subject }.
          to change{ payment.reload.state }.
          from("pending").
          to("failed")
      end
    end

    shared_examples "does nothing" do
      include_examples "processed event"

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

    context "when the event is an event we don't process" do
      let(:event_type) { :pending }
      include_examples "returns the notification"

      it "sets processed to false" do
        expect(subject.processed).to be false
      end
    end
  end
end
