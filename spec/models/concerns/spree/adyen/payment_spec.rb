require "spec_helper"

describe Spree::Adyen::Payment do
  let(:payment) { create :hpp_payment }

  shared_examples "gateway action" do |klass|
    context "when the action succeeds" do
      include_context "mock adyen api", success: true, klass: klass

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
        fault_message: "Expected message",
        klass: klass,
      )

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

  describe "#after_create" do
    include_context "mock adyen api", success: true, klass: Spree::Gateway::AdyenCreditCard
    subject { payment.save! }

    context "when the payment method is an Adyen credit card" do
      let(:payment) { build :adyen_cc_payment, amount: 2000 }

      context "when the source provides encrypted credit card data" do
        before do
          allow_any_instance_of(Spree::CreditCard).
            to receive(:encrypted_data).and_return("SUPERSECRETDATA")
        end

        context "when the authorization succeeds" do
          it "updates the customer's payment profile" do
            expect { subject }.
              to change { payment.source.gateway_customer_profile_id }.
              from(nil).
              to("AWESOMEREFERENCE")
          end
        end

        context "when the authorization fails" do
          include_context(
            "mock adyen api",
            success: false,
            klass: Spree::Gateway::AdyenCreditCard
          )

          it "raises a gateway error and creates a log entry" do
            expect { subject }.to raise_error(Spree::Core::GatewayError).
              and change { Spree::LogEntry.count }.by(1)
          end
        end
      end

      context "when the user selects a stored card" do
        let(:payment) { build :adyen_cc_payment, source: existing_card, amount: 2000 }
        let(:existing_card) { create :credit_card, gateway_customer_profile_id: "123ABC" }

        it "authorizes a recurring payment using the existing contract" do
          expect(provider).to receive(:authorise_recurring_payment)
          subject
        end
      end

      context "when no encrypted credit card data or profile is provided" do
        it "raise a gateway error" do
          expect { subject }.to raise_error(Spree::Core::GatewayError)
        end
      end
    end

    context "when the payment amount is $0" do
      let(:payment) { build :adyen_cc_payment, amount: 0 }

      it "does not create an authorization" do
        expect(payment).to_not receive(:authorize_payment)
        subject
      end
    end

    context "when the payment method is not an Adyen credit card" do
      let(:payment) { build :payment, amount: 2000 }

      it "does not create an authorization" do
        expect(payment).to_not receive(:authorize_payment)
        subject
      end
    end
  end

  describe "purchase!" do
    subject { payment.purchase! }

    context "when the payment method is an Adyen credit card" do
      let(:payment) { create :adyen_cc_payment }
      include_context(
        "mock adyen api",
        success: true,
        klass: Spree::Gateway::AdyenCreditCard
      )

      include_examples "gateway action", Spree::Gateway::AdyenCreditCard

      it "calls captures the payment" do
        expect(payment).to receive(:capture!)
        subject
      end
    end

    context "when the payment method is not an Adyen credit card" do
      let(:payment) { create :payment }

      it "keeps the original behaviour" do
        expect{ subject }.
          to change { payment.reload.state }.
          from("checkout").
          to("completed")
      end
    end
  end

  describe "cancel!" do
    subject { payment.cancel! }
    include_examples "gateway action", Spree::Gateway::AdyenHPP

    context "when the payment doesn't have an hpp source" do
      let(:payment) { create :payment }

      it "keeps the orginal behaviour" do
        expect{ subject }.
          to change { payment.reload.state }.
          from("checkout").
          to("void")
      end
    end

    context "when payment is only manually refundable" do
      let(:payment) { create :hpp_payment, source: source }
      let(:source) { create :hpp_source, :sofort }

      it "creates a log entry" do
        expect { subject }.
          to change { payment.reload.log_entries.count }
      end

      it "doesn't change the state" do
        expect { subject }.
          to_not change { payment.reload.state }
      end
    end
  end

  describe "capture!" do
    subject { payment.capture! }
    include_examples "gateway action", Spree::Gateway::AdyenHPP

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
    include_examples "gateway action", Spree::Gateway::AdyenHPP
  end
end
