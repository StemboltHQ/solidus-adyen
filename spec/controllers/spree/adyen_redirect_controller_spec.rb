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

    xdescribe "GET authorise3d" do
      let(:env) do
        { "HTTP_USER_AGENT" =>
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:29.0) " +
            "Gecko/20100101 Firefox/29.0",
            "HTTP_ACCEPT" =>
          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        }
      end

      context "stubbing Adyen API" do
        let(:params) do
          { MD: "Sooo", PaRes: "Wat" }
        end

        let!(:gateway) { Gateway::AdyenPaymentEncrypted.create!(name: "Adyen") }
        before do
          expect(Gateway::AdyenPaymentEncrypted).to receive(:find).
            and_return gateway

          expect(gateway).to receive(:authorise3d).
            and_return double("Response", success?: true, psp_reference: 1)

          gateway.stub_chain :provider,
            list_recurring_details: double("RecurringDetails", details: [])
        end

        it "redirects user if no recurring detail is returned" do
          spree_get :authorise3d, params,
            { adyen_gateway_name: gateway.class.name,
              adyen_gateway_id: gateway.id }

            expect(response).to redirect_to spree.
              checkout_state_path(order.state)
        end

        it "payment need to be in processing state so it's not authorised twice" do
          details = { card: {
            expiry_date: 1.year.from_now,
            number: "1111" },
            recurring_detail_reference: "123432423" }

          gateway.stub_chain :provider,
            list_recurring_details: double("RecurringDetails",
                                           details: [details])

            spree_get :authorise3d, params,
              { adyen_gateway_name: gateway.class.name,
                adyen_gateway_id: gateway.id }

              expect(Payment.last.state).to eq "processing"
        end
      end

      context "reaching Adyen API", external: true do
        let(:params) do
          { MD: test_credentials["controller_md"],
            PaRes: test_credentials["controller_pa_response"] }
        end

        let!(:gateway) do
          Gateway::AdyenPaymentEncrypted.create!(
            name: "Adyen",
            preferred_api_username: test_credentials["api_username"],
            preferred_api_password: test_credentials["api_password"],
            preferred_merchant_account: test_credentials["merchant_account"]
          )
        end

        before do
          order.user_id = 1
          ActionController::TestRequest.any_instance.stub(:ip).
            and_return("127.0.0.1")

          ActionController::TestRequest.any_instance.
            stub_chain(:headers, env: env)
        end

        it "redirects user to confirm step" do
          VCR.use_cassette("3D-Secure-authorise-redirect-controller") do
            spree_get :authorise3d, params,
              { adyen_gateway_name: gateway.class.name,
                adyen_gateway_id: gateway.id }

              expect(response).to redirect_to spree.
                checkout_state_path("confirm")
          end
        end

        it "set up payment" do
          VCR.use_cassette("3D-Secure-authorise-redirect-controller") do
            expect {
              spree_get :authorise3d, params,
              { adyen_gateway_name: gateway.class.name,
                adyen_gateway_id: gateway.id }
            }.to change { Payment.count }.by(1)
          end
        end

        it "set up credit card with recurring details" do
          VCR.use_cassette("3D-Secure-authorise-redirect-controller") do
            expect {
              spree_get :authorise3d, params,
              { adyen_gateway_name: gateway.class.name,
                adyen_gateway_id: gateway.id }
            }.to change { CreditCard.count }.by(1)

            expect(CreditCard.last.gateway_customer_profile_id).
              to be_present
          end
        end
      end
    end
  end
end
