require 'spec_helper'

# https://docs.adyen.com/display/TD/HPP+payment+response
module Spree
  RSpec.describe AdyenRedirectController do
    let(:order) { create(:order_with_line_items, state: "payment") }

    before do
      allow(controller).to receive(:current_order).and_return order
    end

    describe "GET confirm" do
      subject(:action) { spree_get :confirm, params }

      let(:auth_result) { "AUTHORISED" }
      let(:params) do
        { merchantReference: order.number,
          skinCode: "Nonenone",
          shopperLocale: "en_GB",
          paymentMethod: "visa",
          authResult: auth_result,
          pspReference:  psp_reference,
          merchantSig: "erewrwerewrewrwer" }
      end

      let(:psp_reference) { "8813824003752247" }
      let(:payment_method) { Gateway::AdyenHPP.create(
        name: "Adyen", environment: 'test') }

      before do
        allow(controller).to receive(:check_signature)
        allow(controller).to receive(:payment_method).
          and_return payment_method
      end

      it "creates a payment for the current order" do
        expect{ subject }.to change { order.payments.count }.from(0).to(1)
      end

      it "redirects to order complete page" do
        expect(subject).to redirect_to spree.order_path(
          order, token: order.guest_token)
      end

      describe "the order" do
        subject { order }
        before { action }
        it "is in the completed state" do
          expect(subject.state).to eq 'complete'
        end
      end

      describe "created payment" do
        subject { order.payments.last }
        before { action }

        it "has attributes from the request" do
          is_expected.to have_attributes(
            amount: order.total,
            payment_method: payment_method,
            response_code: psp_reference)
        end

        it "creates a source for the payment" do
          expect(subject.source).
            to be_an_instance_of(Adyen::HppSource).
            and(have_attributes(
              merchant_reference: order.number,
              skin_code: "Nonenone",
              shopper_locale: "en_GB",
              payment_method: "visa",
              auth_result: auth_result,
              psp_reference:  psp_reference,
              merchant_sig: "erewrwerewrewrwer"
            ))
        end
      end

      context "when the payment is not authorised" do
        let(:auth_result) { "ERROR" }

        it { is_expected.to redirect_to spree.checkout_state_path("payment") }

        it "sets the flash" do
          subject
          expect(flash[:notice]).to eq 'Payment could not be processed, please'\
            ' check the details you entered'
        end

        describe 'the order' do
          subject { order }
          before { action }
          it 'is in the payment state' do
            is_expected.to be_payment
          end
        end
      end
    end
  end
end
