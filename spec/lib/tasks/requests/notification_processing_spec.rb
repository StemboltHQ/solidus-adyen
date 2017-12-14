require "spec_helper"

RSpec.describe "Notification processing", type: :request do
  before do
    allow_any_instance_of(Spree::AdyenRedirectController).
      to receive(:check_signature)

    ENV["ADYEN_NOTIFY_USER"] = "spree_user"
    ENV["ADYEN_NOTIFY_PASSWD"] = "1234"

    # push the order through to payment
    while order.state != "payment"
      order.next!
    end
  end

  let!(:order) { create :order_with_line_items, number: "R207199925" }

  let!(:payment_method) do
    create(
      :hpp_gateway,
      preferred_api_username: "username",
      preferred_api_password: "password"
    )
  end

  let(:auth_params) do
    {
      "originalReference" => "",
      "reason" => "21633:0002:8/2018",
      "additionalData.hmacSignature" => "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      "additionalData.authCode" => "21633",
      "additionalData.expiryDate" => "8/2018",
      "additionalData.cardHolderName" => "John Doe",
      "additionalData.cardSummary" => "0002",
      "merchantAccountCode" => "xxxxxxxxxxxxxxxxxxxxxxxxxx",
      "eventCode" => "AUTHORISATION",
      "operations" => "CANCEL,CAPTURE,REFUND",
      "additionalData.cardBin" => "370000",
      "success" => "true",
      "paymentMethod" => "amex",
      "currency" => "EUR",
      "pspReference" => "7914483013255061",
      "merchantReference" => "R207199925",
      "value" => "2200",
      "live" => "false",
      "eventDate" => "2015-11-23T17:55:25.30Z"
    }
  end

  let(:capture_params) do
    {
      "originalReference" => "7914483013255061",
      "reason" => "",
      "additionalData.hmacSignature" => "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      "merchantAccountCode" => "xxxxxxxxxxxxxxxxxxxxxxxxxx",
      "eventCode" => "CAPTURE",
      "operations" => "",
      "success" => "true",
      "paymentMethod" => "amex",
      "currency" => "EUR",
      "pspReference" => "8614483013279252",
      "merchantReference" => "R207199925",
      "value" => "2200",
      "live" => "false",
      "eventDate" => "2015-11-23T17:55:27.00Z"
    }
  end

  let(:checkout_params) do
    {
      "merchantReference" => "R207199925",
      "skinCode" => "xxxxxxxx",
      "shopperLocale" => "en",
      "paymentMethod" => "amex",
      "authResult" => "AUTHORISED",
      "pspReference" => "7914483013255061",
      "merchantReturnData" => "adKbcFeXxOVE76UJRDF88g|#{payment_method.id}",
      "merchantSig" => "SBdhua18U+8xkPmK/a/8VprF230="
    }
  end

  let(:headers) do
    {
      "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.
        encode_credentials("spree_user", "1234")
    }
  end

  describe "full redirect, auth, capture flow", truncation: true do
    it "creates a payment, completes order, captures payment" do
      VCR.use_cassette "adyen capture" do
        expect {
          initial_authorization
        }.to(
          change { order.payments.count }.by(1).
          and change { order.reload.state}.to("complete").
          and change { AdyenNotification.count }.by(1)
        )

        expect {
          capture_notification
        }.to change {
          order.payments.last.reload.state
        }.from("processing").to("completed")
      end
    end
  end

  context "no psp reference in redirect" do
    describe "full redirect, auth, capture flow", truncation: true do
      let(:checkout_params) do
        {
          "merchantReference" => "R207199925",
          "skinCode" => "xxxxxxxx",
          "shopperLocale" => "en",
          "paymentMethod" => "amex",
          "authResult" => "AUTHORISED",
          "merchantReturnData" => "adKbcFeXxOVE76UJRDF88g|#{payment_method.id}",
          "merchantSig" => "SBdhua18U+8xkPmK/a/8VprF230="
        }
      end

      it "adds in psp reference to payment" do
        VCR.use_cassette "adyen capture" do
          expect {
            initial_authorization
          }.to(
            change { order.payments.count }.by(1).
            and change { order.reload.state}.to("complete").
            and change { AdyenNotification.count }.by(1)
          )

          expect {
            capture_notification
          }.to change {
            order.payments.last.reload.state
          }.from("processing").to("completed")

          expect(order.payments.first.response_code).to eq "7914483013255061"
        end
      end
    end
  end

  def initial_authorization
    redirect_request
    authorize_notification
  end

  def authorize_notification
    notification = AdyenNotification.build(auth_params)
    notification.save!
    Spree::Adyen::NotificationJob.perform_now(notification)
  end

  def redirect_request
    get "/checkout/payment/adyen", params: checkout_params, headers: headers
    expect(response.status).to eq(302)
  end

  def capture_notification
    notification = AdyenNotification.build(capture_params)
    notification.save!
    Spree::Adyen::NotificationJob.perform_now(notification)
  end
end
