require "spec_helper"

describe Spree::Adyen::Payment do
  let(:payment) { create :hpp_payment }

  shared_examples "gateway action" do
    context "when the action succeeds" do
      include_context "mock adyen client", success: true

      it "logs the response" do
        expect{ subject }.to change{ payment.reload.log_entries.count }.by(1)
      end

      it "changes payment state to processing" do
        expect{ subject }.to change{ payment.state }.to("processing")
      end
    end

    context "when the action fails" do
      include_context(
        "mock adyen client",
        success: false,
        fault_message: "Expected message",
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
    include_context("mock adyen client", success: true, psp_reference: "TRANSACTION_SUCCESS")

    subject { payment.save! }

    context "when the payment method is Ratepay" do
      let(:payment) { build :ratepay_payment, source: ratepay, amount: 1500 }

      context "and no Date of Birth was provided" do
        let(:ratepay) { create :ratepay_source }

        it "raises an error" do
          expect { subject }.to raise_error(
            Spree::Gateway::AdyenRatepay::MissingDateOfBirthError,
            "Date of birth is required for invoice transactions."
          )
        end
      end

      context "and the date of birth is set on the source" do
        let(:ratepay) { create :ratepay_source, :dob_provided }

        context "and the authorization succeeds" do
          it "updates the source" do
            expect { subject }.to change { payment.source.psp_reference }.to("TRANSACTION_SUCCESS")
          end

          it "updates the payment" do
            expect { subject }.to change { payment.response_code }.to("TRANSACTION_SUCCESS")
          end
        end

        context "and the authorization fails" do
          include_context(
            "mock adyen client",
            success: false,
            fault_message: "Invoice rejected"
          )

          it "raises an error and creates a log entry" do
            expect { subject }.to raise_error(
              Spree::Gateway::AdyenRatepay::InvoiceRejectedError,
              "Invoice rejected"
            ).and change { Spree::LogEntry.count }.by(1)
          end
        end
      end
    end

    context "when the payment amount is $0" do
      let(:payment) { build :ratepay_payment, amount: 0 }

      it "does not create an authorization" do
        expect(payment).to_not receive(:authorize_payment)
        subject
      end
    end

    context "when the payment method should not be authorized on creation" do
      let(:payment) { build :payment, amount: 2000 }

      it "does not create an authorization" do
        expect(payment).to_not receive(:authorize_payment)
        subject
      end
    end
  end

  describe "authorize!" do
    subject { payment.authorize! }

    context "paying with a credit card" do
      let(:card) { create(:credit_card, adyen_token: "TESTTOKEN") }
      let(:payment) { create(:adyen_cc_payment, source: card) }

      context "payment succeeds" do
        include_context("mock adyen client", success: true)

        it "changes the state to pending" do
          expect { subject }.to change { payment.state }.from("checkout").to("pending")
        end

        it "updates the user's card data" do
          expect { subject }.to change { card.gateway_customer_profile_id }.
            from(nil).to("AWESOMEREFERENCE")
        end
      end

      context "payment fails" do
        include_context("mock adyen client", success: false, fault_message: "Payment failed")

        it "raises a gateway error with the failure message" do
          expect { subject }.to raise_error(
            Spree::Core::GatewayError,
            "Payment failed"
          )
        end
      end
    end
  end

  describe "purchase!" do
    subject { payment.purchase! }

    context "when the payment method is an Adyen credit card" do
      let(:card) { create(:credit_card, adyen_token: "TESTTOKEN") }
      let(:payment) { create :adyen_cc_payment, source: card }

      include_context(
        "mock adyen client",
        success: true,
      )

      context "payment succeeds" do
        it "calls authorize! and capture! on the payment" do
          expect(payment).to receive(:authorize!)
          expect(payment).to receive(:capture!)
          subject
        end
      end

      context "payment fails" do
        include_context("mock adyen client", success: false, fault_message: "Payment failed")

        it "raises a gateway error and marks the payment as failed" do
          expect { subject }.to raise_error(
            Spree::Core::GatewayError,
            "Payment failed"
          ).and change { payment.state }.from("checkout").to("failed")
        end
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
