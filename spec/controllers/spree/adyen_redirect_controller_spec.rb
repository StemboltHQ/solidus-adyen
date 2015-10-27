require 'spec_helper'

# https://docs.adyen.com/display/TD/HPP+payment+response
RSpec.describe Spree::AdyenRedirectController, type: :controller do
  let(:order) { create(:order_with_line_items, state: "payment") }
  let(:payment_method) { create :bogus_hpp_gateway }

  before do
    allow(controller).to receive(:current_order).and_return order
    allow(controller).to receive(:check_signature)
    allow(controller).to receive(:payment_method).
      and_return payment_method
  end

  describe "GET confirm" do
    subject(:action) { spree_get :confirm, params }

    let(:psp_reference) { "8813824003752247" }
    let(:params) do
      { merchantReference: order.number,
        skinCode: "xxxxxxxx",
        shopperLocale: "en_GB",
        paymentMethod: "visa",
        authResult: auth_result,
        pspReference:  psp_reference,
        merchantSig: "erewrwerewrewrwer"
      }
    end

    shared_examples "payment is successful" do
      it "changes the order state to completed" do
        expect{ subject }.
          to change{ order.state }.
          from("payment").
          to("complete")
      end

      it "redirects to the order complete page" do
        is_expected.to have_http_status(:redirect).
          and redirect_to order_path(order)
      end

      it "creates a pending payment" do
        expect{ subject }.
          to change{ order.payments.count }.
          from(0).
          to(1)

        expect(order.payments).to all be_pending
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
      let(:auth_result) { "AUTHORISED" }
    end

    context "when the payment is PENDING" do
      include_examples "payment is successful"
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
