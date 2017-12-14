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
    subject { post :notify, params: params }

    shared_examples "success" do
      it "acknowledges the request" do
        expect {
          subject
          expect(response.status).to eq(200)
          expect(response.body).to eq("[accepted]")
        }.to have_enqueued_job(Spree::Adyen::NotificationJob)
      end
    end

    context "request authenticated" do
      before { bypass_auth }

      include_examples "success"

      it "creates a notification" do
        expect{ subject }.to change { AdyenNotification.count }.from(0).to(1)
      end

      context "when the system can't find a matching payment" do
        let(:payment) { nil }

        include_examples "success"

        it "creates a notification" do
          expect{ subject }.to change { AdyenNotification.count }.from(0).to(1)
        end
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
        post :notify, params: params

        expect{ post :notify, params: params }.
          to_not change{ AdyenNotification.count }
      end
    end
  end

  def bypass_auth
    @request.env["HTTP_AUTHORIZATION"] = "Basic " +
      Base64::encode64("username:password")
  end
end
