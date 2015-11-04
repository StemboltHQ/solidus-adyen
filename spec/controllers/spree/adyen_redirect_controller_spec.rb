require "spec_helper"

# https://docs.adyen.com/display/TD/HPP+payment+response
RSpec.describe Spree::AdyenRedirectController, type: :controller do
  include_context "mock adyen api", success: true

  let(:order) { create(:order_with_line_items, state: "payment") }
  let(:gateway) { create :hpp_gateway }

  before do
    allow(controller).to receive(:current_order).and_return order
    allow(controller).to receive(:check_signature)
    allow(controller).to receive(:payment_method).
      and_return gateway
  end

  describe "GET confirm" do
    subject(:action) { spree_get :confirm, params }

    let(:psp_reference) { "8813824003752247" }
    let(:payment_method) { "amex" }
    let(:params) do
      { merchantReference: order.number,
        skinCode: "xxxxxxxx",
        shopperLocale: "en_GB",
        paymentMethod: payment_method,
        authResult: auth_result,
        pspReference:  psp_reference,
        merchantSig: "erewrwerewrewrwer"
      }
    end

    shared_examples "payments are pending" do
      it "has pending payments" do
        expect(order.payments).to all be_pending
      end
    end

    shared_examples "payment is successful" do
      it "changes the order state to completed" do
        expect { subject }.
          to change { order.reload.state }.
          from("payment").
          to("complete").

          and change { order.payment_state }.
          from(nil).
          to("balance_due").

          and change { order.shipment_state }.
          from(nil).
          to("pending")
      end

      it "redirects to the order complete page" do
        is_expected.to have_http_status(:redirect).
          and redirect_to order_path(order)
      end

      it "creates a payment" do
        expect{ subject }.
          to change{ order.payments.count }.
          from(0).
          to(1)
      end

      context "and the order cannot complete" do
        before do
          expect(order).to receive(complete).and_return(false)
        end

        it "voids the payment"
      end
    end

    context "when the payment is AUTHORISED" do
      include_examples "payment is successful"
      include_examples "payments are pending"
      let(:auth_result) { "AUTHORISED" }

      context "and the authorisation notification has already been received" do
        let(:payment_method) { notification.payment_method }

        let(:notification) do
          create(
            :notification,
            notification_type,
            psp_reference: psp_reference,
            merchant_reference: order.number)
        end

        shared_examples "auth received" do
          include_examples "payment is successful"

          it "processes the notification" do
            expect { subject }.
              to change { notification.reload.processed }.
              from(false).
              to(true)
          end
        end

        context "and payment method is sofort" do
          let(:notification_type) { :sofort_auth }
          include_examples "auth received"
        end

        context "and payment method is ideal" do
          let(:notification_type) { :ideal_auth }
          include_examples "auth received"
        end

        context "and payment method is credit" do
          let(:notification_type) { :auth }
          include_examples "auth received"
        end
      end
    end

    context "when the payment is PENDING" do
      include_examples "payment is successful"
      include_examples "payments are pending"
      let(:auth_result) { "PENDING" }
    end

    shared_examples "payment is not successful" do
      it "does not change order state" do
        expect{ subject }.to_not change{ order.state }
      end

      it "redirects to the order payment page" do
        is_expected.to have_http_status(:redirect).
          and redirect_to checkout_state_path("payment")
      end
    end

    context "when the payment is CANCELLED" do
      include_examples "payment is not successful"
      let(:auth_result) { "CANCELLED" }
    end

    context "when the payment is REFUSED" do
      include_examples "payment is not successful"
      let(:auth_result) { "REFUSED" }
    end
  end
end
