require "spec_helper"

RSpec.describe Spree::Adyen::NotificationProcessor do
  include_context "mock adyen api", success: true

  describe "#process" do
    subject { described_class.new(notification).process! }

    let!(:payment) do
      create(
        :payment,
        amount: 23.99,
        state: payment_state,
        payment_method: hpp_gateway,
        order: create(:order, currency: "EUR")
      )
    end

    let!(:hpp_gateway) do
      create(:hpp_gateway)
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

    context "when event is CANCEL_OR_REFUND" do
      let(:event_type) { :cancel_or_refund }

      before do
        payment.complete
      end

      it "voids the payment" do
        expect { subject }.
          to change { payment.reload.state }.
          from("completed").
          to("void")
      end
    end

    context "when event is REFUND" do
      let(:event_type) { :refund }
      let(:payment_state) { "processing" }

      it "creates a refund" do
        expect { subject }.
          to change { payment.reload.refunds.count }.
          from(0).
          to(1)
      end

      it "changes the payment state to completed" do
        expect { subject }.
          to change { payment.reload.state }.
          from("processing").
          to("completed")
      end
    end

    context "when the event is an event we don't process" do
      let(:event_type) { :pending }
      include_examples "returns the notification"

      it "sets processed to false" do
        expect(subject.processed).to be false
      end
    end
  end

  describe "#process_outstanding!" do
    subject { described_class.process_outstanding! payment }

    let!(:payment) { create :hpp_payment, amount: 19.99, state: "pending" }

    let!(:notifications) do
      opts = {payment: payment, value: 1999}
      [
        create(:notification, :auth, **opts),
        create(:notification, :capture, **opts)
      ]
    end

    it "processes all notifications" do
      subject
      notifications.map(&:reload)
      expect(notifications).to all be_processed
    end

    it "modifies the payment" do
      expect { subject }.
        to change { payment.state }.from("pending").to("completed").

        and change { payment.captured_amount }.from(0).to(19.99)
    end
  end
end
