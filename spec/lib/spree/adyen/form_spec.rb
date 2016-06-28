require "spec_helper"

RSpec.describe Spree::Adyen::HPP do
  let(:order) { create :order, total: 39.98 }
  let(:payment_method) { create :hpp_gateway, preferences: preferences }
  let(:preferences){
    {server: "test",
     test_mode: true,
     api_username: "username",
     api_password: "password",
     merchant_account: "account",
     skin_code: "XXXXXX",
     shared_secret: "1234567890",
     days_to_ship: 3}
  }
  let(:locale) { I18n.locale.to_s.gsub("-", "_") }

  describe "directory_url" do
    let(:expected) do
      redirect_params = {
        currency_code: order.currency,
        ship_before_date: 3.days.from_now,
        session_validity: 10.minutes.from_now,
        recurring: false,
        merchant_reference: order.number.to_s,
        merchant_account: payment_method.merchant_account,
        skin_code: payment_method.skin_code,
        shared_secret: payment_method.shared_secret,
        country_code: order.billing_address.country.iso,
        merchant_return_data: merchant_return_data,
        payment_amount: 3998,
        shopper_locale: locale,
        shopper_email: order.email
      }

      ::Adyen::HPP::Request.new(redirect_params, skin: { skin_code: 'XXXXXX' }).redirect_url
    end

    let(:merchant_return_data) do
      [order.guest_token, payment_method.id].join("|")
    end

    subject { described_class.directory_url order, payment_method  }

    it "has the same query options as Adyen gem's" do
      expect(hash_query subject).to eq hash_query expected
    end

    it "has the proper protocol" do
      expect(URI(subject).scheme).to eq "https"
    end

    it "the right host" do
      expect(URI(subject).host).to eq "test.adyen.com"
    end

    context "when in production" do
      before do
        payment_method.preferences[:server] = "live"
      end

      it "has the proper protocol and host" do
        expect(URI(subject).host).to eq "live.adyen.com"
      end
    end
  end

  describe "payment_methods" do
    let(:adyen_response) { '{ "test": "response" }' }
    let(:fake_directory_url) { "www.directory-url.com" }

    before do
      allow(described_class).to receive(:directory_url).
        and_return(fake_directory_url)
      allow(::Net::HTTP).to receive(:get).
        with(fake_directory_url).
        and_return(adyen_response)
    end

    subject { described_class.send(:payment_methods, order, payment_method) }

    it "calls form_payment_methods_and_urls with adyen response" do
      expect(described_class).to receive(:form_payment_methods_and_urls).
        with({ "test" => "response" }, order, payment_method)
      subject
    end
  end

  describe "form_payment_methods_and_urls" do
    let(:payment_url) { "www.test-url.com" }
    let(:issuer_payment_url) { "www.issuer-test-url.com" }

    before do
      allow(described_class).to receive(:details_url).
        and_return(payment_url)
      allow(described_class).to receive(:details_url_with_issuer).
        and_return(issuer_payment_url)

    end

    subject { described_class.send(
      :form_payment_methods_and_urls,
      adyen_response,
      order,
      payment_method
    ) }

    context "payment method without issuers" do
      let(:adyen_response) {
        {
          "paymentMethods" => [
            {
              "brandCode" => "paypal",
              "name" => "PayPal"
            }
          ]
        }
      }

      it "returns processed response with urls" do
        expect(subject).to eq [
          {
            name: "PayPal",
            brand_code: "paypal",
            payment_url: payment_url,
            issuers: []
          }
        ]
      end
    end

    context "payment method with issuers" do
      let(:adyen_response) {
        {
          "paymentMethods" => [
            {
              "brandCode" => "ideal",
              "name" => "iDEAL",
              "issuers" => [
                {
                  "name" => "issuer01",
                  "issuerId" => "1157"
                },
                {
                  "name" => "issuer02",
                  "issuerId" => "1184"
                }
              ]
            }
          ]
        }
      }

      it "returns processed response with urls" do
        expect(subject).to eq [
          {
            name: "iDEAL",
            brand_code: "ideal",
            payment_url: payment_url,
            issuers: [
              {
                name: "issuer01",
                payment_url: issuer_payment_url
              },
              {
                name: "issuer02",
                payment_url: issuer_payment_url
              }
            ]
          }
        ]
      end
    end

    context "when payment_method specifies restricted brand_codes" do
      let(:adyen_response) {
        {
          "paymentMethods" => [
            {
              "brandCode" => "mc",
              "name" => "MasterCard"
            }, {
              "brandCode" => "paypal",
              "name" => "PayPal"
            }
          ]
        }
      }

      let(:payment_method) { create(:hpp_gateway, :with_restricted_brand_codes) }

      it "will only return paypal brand_code" do
        expect(subject).to eq [
          {
            name: "PayPal",
            brand_code: "paypal",
            payment_url: payment_url,
            issuers: []
          }
        ]
      end
    end
  end

  describe "details_url" do
    let(:brand_code) { "paypal" }
    subject {
      described_class.details_url(order, payment_method, brand_code)
    }

    it "calls endpoint url with the expected params" do
      expect(described_class).to receive(:endpoint_url).
        with("details", order, payment_method, { brandCode: "paypal" })
      subject
    end
  end

  describe "pay_url" do
    subject {
      described_class.pay_url(order, payment_method)
    }

    it "calls endpoint url with the expected params" do
      expect(described_class).
          to receive(:endpoint_url).
          with("pay", order, payment_method)
      subject
    end
  end

  describe "details_url_with_issuer" do
    let(:issuer_id) { "1654" }
    let(:brand_code) { "paypal" }

    subject {
      described_class.details_url_with_issuer(
        order,
        payment_method,
        brand_code,
        issuer_id
      )
    }

    it "calls endpoint url with the expected params" do
      expect(described_class).to receive(:endpoint_url).
        with(
          "details",
          order,
          payment_method,
          { brandCode: "paypal", issuerId: "1654" }
        )
      subject
    end
  end

  def hash_query url
    CGI::parse URI(url).query
  end
end
