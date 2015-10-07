require "spec_helper"

RSpec.describe Spree::Adyen::Form do
  describe "directory_url" do
    let(:order) { create :order, total: 99.0 }

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
        country_code: order.billing_address.country.iso3,
        payment_amount: (order.total.to_f * 100).to_int }

       ::Adyen::Form.redirect_url(redirect_params)
    end

    subject { described_class.directory_url order, payment_method  }

    it "has the same query options as Adyen gem's" do
      expect(hash_query subject).to eq hash_query expected
    end

    it 'has the proper protocol' do
      expect(URI(subject).scheme).to eq 'https'
    end

    it 'the right host' do
      expect(URI(subject).host).to eq 'test.adyen.com'
    end

    context 'when in production' do
      before do
        payment_method.preferences[:server] = 'live'
      end

      it 'has the proper protocol and host' do
        expect(URI(subject).host).to eq 'live.adyen.com'
      end
    end
  end

  def hash_query url
    CGI::parse URI(url).query
  end
end
