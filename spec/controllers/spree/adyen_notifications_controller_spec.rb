require "spec_helper"

describe Spree::AdyenNotificationsController do
  include_context "mock adyen client", success: true

  routes { Spree::Core::Engine.routes }

  let(:params) do
    { "pspReference" => reference,
      "eventDate" => "2013-10-21T14:45:45.93Z",
      "merchantAccountCode" => "Test",
      "reason" => "41061:1111:6/2016",
      "originalReference" => "",
      "value" => "6999",
      "eventCode" => "AUTHORISATION",
      "merchantReference" => order.number,
      "operations" => "CANCEL,CAPTURE,REFUND",
      "success" => "true",
      "paymentMethod" => "visa",
      "currency" => "USD",
      "live" => "false" }
  end

  let!(:order) { create :completed_order_with_totals }

  let!(:payment) do
    create(
      :hpp_payment,
      response_code: reference,
      payment_method: payment_method,
      order: order,
      source: create(
        :hpp_source,
        psp_reference: reference,
        order: order
      )
    )
  end

  let!(:payment_method) { create :hpp_gateway }

  let(:reference) { "8513823667306210" }

  before do
    ENV["ADYEN_NOTIFY_USER"] = "username"
    ENV["ADYEN_NOTIFY_PASSWD"] = "password"
  end

  describe "POST notify" do
    subject { post :notify, params }

    shared_examples "success" do
      it "acknowledges the request" do
        subject
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq("[accepted]")
      end
    end

    context "request authenticated" do
      before { bypass_auth }

      shared_examples "logs the notification" do
        include_examples "success"
        it "creates a notification" do
          expect{ subject }.to change { AdyenNotification.count }.from(0).to(1)
        end
      end

      include_examples "logs the notification"

      context "when the system can't find a matching payment" do
        let(:payment) { nil }
        include_examples "logs the notification"
      end

      # Regression test
      # In the event that a notification cannot be processed we need to still
      # save the notification and acknoweldge it - otherwise Adyen will
      # continue to notify us about the event and it will continue to error it.
      #
      # We cannot use an `ensure` in the controller action because the render
      # actually completes after the action. Doing so still results in a 500.
      #
      # For this reason we need to save the notification on the first attempt,
      # let the controller error, and then on the second attempt from Adyen
      # return 200 [accepted], as the notification has already been saved.
      context "an error occurs during processing" do
        before { payment.void! }
        before { params["success"] = false }

        it "errors and creates a notification" do
          expect {
            expect { post(:notify, params) }.
            to raise_error(StateMachines::InvalidTransition)

            expect(post(:notify, params)).
              to have_http_status(:ok).
              and have_attributes(body: "[accepted]")
          }.
          to change { AdyenNotification.count }.by(1)
        end
      end

      context "notification contains a long report filename" do
        let(:params) do
          { "reason" => "https://ca-test.adyen.com/reports/download/MerchantAccount/"\
            "A_Client_with_a_long_merchant_account/invoice-201605000203.MerchantAccount."\
            "A_Client_with_a_long_merchant_account-UK_WO.pdf",
            "merchantAccountCode" => "A_Client_with_a_long_merchant_account",
            "eventCode" => "REPORT_AVAILABLE",
            "success" => "true",
            "currency" => "GBP",
            "pspReference" => "invoice-201605000203.MerchantAccount.A_Client_with_a_long_merchant_account-UK_WO.pdf",
            "value" => "0",
            "live" => "false",
            "eventDate" => "2016-06-08T17:48:54.79Z" }
        end

        before { bypass_auth }

        include_examples "logs the notification"
      end
    end

    context "request not authenticated" do
      it { is_expected.to have_http_status 401 }
    end

    context "notification has already been received" do
      before { bypass_auth }
      include_examples "success"

      it "doesn't create a notification" do
        # explict call of subject to avoid memoization
        post :notify, params

        expect{ post :notify, params }.
          to_not change{ AdyenNotification.count }
      end
    end
  end

  def bypass_auth
    @request.env["HTTP_AUTHORIZATION"] = "Basic " +
      Base64::encode64("username:password")
  end
end
