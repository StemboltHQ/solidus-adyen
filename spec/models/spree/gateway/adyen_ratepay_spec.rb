require 'spec_helper'

describe Spree::Gateway::AdyenRatepay do
  let(:ratepay) { build_stubbed :ratepay_gateway }

  describe "#partial_name" do
    it "is always 'adyen_ratepay'" do
      expect(ratepay.partial_name).to eq "adyen_ratepay"
    end
  end

  describe "#payment_source_class" do
    it "uses the Ratepay source" do
      expect(ratepay.payment_source_class).to eq Spree::Adyen::RatepaySource
    end
  end

  describe "#authorize" do
    subject { ratepay.authorize(200, nil, {}) }

    it "returns a mock successful ActiveMerchant::Billing response" do
      expect(subject).to be_a ActiveMerchant::Billing::Response
      expect(subject.success?).to be true
    end
  end
end
