require "spec_helper"

RSpec.describe Spree::Api::AdyenRedirectController, type: :controller do
  include_context "mock adyen client", success: true

  let(:order) do
    create(
      :order_with_line_items,
      state: "payment",
      store: store
    )
  end

  let!(:store) { create :store }
  let!(:gateway) { create :hpp_gateway }

  before do
    allow_any_instance_of(Spree::Ability).to receive(:can?).and_return(true)

    stub_authentication!

    allow(controller).to receive(:check_signature)

    allow(Spree::Order).to receive(:find_by!).
      with(number: order.number).
      and_return(order)
  end

  subject {  }

  describe "confirm" do
    subject(:action) { post :confirm, params.reverse_merge!({ format: :json }) }

    let(:psp_reference) { "8813824003752247" }
    let(:payment_method) { "amex" }
    let(:merchantReturnData) { "#{order.guest_token}|#{gateway.id}" }
    let(:params) do
      { order_id: order.number,
        merchantReference: order.number,
        skinCode: "xxxxxxxx",
        shopperLocale: "en_GB",
        paymentMethod: payment_method,
        authResult: auth_result,
        pspReference:  psp_reference,
        merchantSig: "erewrwerewrewrwer",
        merchantReturnData: merchantReturnData
      }
    end

    shared_examples "api payment is successful" do
      it "changes the order state to completed" do
        subject
        order.reload
        expect(order).to have_attributes(
          state: "complete",
          payment_state: "balance_due",
          shipment_state: "pending"
        )
      end

      it "has pending payments" do
        expect(order.payments).to all be_pending
      end

      it "renders an order in complete state" do
        is_expected.to have_http_status(:ok)
      end

      it "creates a payment" do
        subject
        expect(order.reload.payments.count).to eq 1
      end

      context "and the order cannot complete" do
        before do
          expect(order).to receive(complete).and_return(false)
        end

        it "voids the payment"
      end
    end

    shared_examples "api payment is not successful" do
      it "does not change order state" do
        expect{ subject }.to_not change{ order.state }
      end

      it "redirects to the order payment page" do
        is_expected.to have_http_status(422)
      end
    end

    context "when the payment is AUTHORISED" do
      include_examples "api payment is successful"

      let(:auth_result) { "AUTHORISED" }

      context "and the authorisation notification has already been received" do
        let(:payment_method) { notification.payment_method }

        let(:notification) do
          create(
            :notification,
            :auth,
            processed: true,
            psp_reference: psp_reference,
            merchant_reference: order.number)
        end

        let(:source) { create(:hpp_source, psp_reference: psp_reference, order: order) }

        before do
          create(:hpp_payment, source: source, order: order)

          order.contents.advance
          order.complete
        end

        it { expect { subject }.to_not change { order.payments.count }.from 1 }

        it "updates the source" do
          expect(order.payments.last.source).to have_attributes(
            auth_result: "AUTHORISED",
            skin_code: "XXXXXXXX"
          )
        end

        include_examples "api payment is successful"
      end
    end

    context "when the payment is PENDING" do
      include_examples "api payment is successful"
      let(:auth_result) { "PENDING" }
    end

    context "when the payment is CANCELLED" do
      include_examples "api payment is not successful"
      let(:auth_result) { "CANCELLED" }
    end

    context "when the payment is REFUSED" do
      include_examples "api payment is not successful"
      let(:auth_result) { "REFUSED" }
    end
  end
end
