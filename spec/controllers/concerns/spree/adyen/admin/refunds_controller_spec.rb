require "spec_helper"

RSpec.describe Spree::Admin::RefundsController do
  stub_authorization!
  include_context "mock adyen api", success: true
  routes { Spree::Core::Engine.routes }

  describe "POST create" do
    subject { post :create, params }

    let(:params) do
      {
        "refund" => {
          "amount" => amount,
          "refund_reason_id" => reason.id
        },
        "order_id" => order.number,
        "payment_id" => payment.id
      }
    end

    let(:reason) { create :refund_reason }
    let(:order) { create :order, currency: "EUR" }
    let(:amount) { 100.0 }
    let(:payment_opts) { {state: "completed", amount: 100.0} }

    before do
      payment.capture_events.create!(amount: 100.0)
    end

    context "when the payment comes from Adyen Hosted Payment Pages" do
      let(:payment) { create :hpp_payment, order: order, **payment_opts }

      it "does not create the record" do
        expect { subject }.to_not change { payment.reload.refunds.count }
      end

      it "sets the success flash" do
        subject
        expect(flash[:success]).to eq "Refund request was received"
      end

      it "requests the refund" do
        expect_any_instance_of(Spree::Payment).
          to receive(:adyen_hpp_credit!).
          with(10000, currency: "EUR")
        subject
      end

      it { is_expected.to have_http_status :redirect }

      context "and the refund is invalid" do
        let(:amount) { 0 }

        it "displays an error" do
          is_expected.to have_http_status :ok
          expect(flash[:error]).to be_present
        end

        it "doesn't attempt to credit the payment" do
          expect_any_instance_of(Spree::Payment).
            to_not receive(:adyen_hpp_credit!)
          subject
        end
      end
    end

    context "when any other kind of payment" do
      let(:payment) { create :payment, **payment_opts }

      it "creates the refund" do
        expect { subject }.to change { payment.reload.refunds.count }.by(1)
      end
    end
  end
end
