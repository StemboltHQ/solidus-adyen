require 'spec_helper'

describe Spree::AdyenNotificationsController do
  routes { Spree::Core::Engine.routes }

  let(:order) { create :order }
  let(:params) do
    { "pspReference" => "8513823667306210",
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

      include_examples "success"

      it "creates a notification" do
        expect{ subject }.to change { AdyenNotification.count }.from(0).to(1)
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
