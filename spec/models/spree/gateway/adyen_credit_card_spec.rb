require 'spec_helper'

describe Spree::Gateway::AdyenCreditCard do
  it { is_expected.to be_a(Spree::Gateway) }

  describe 'provider_class' do
    subject { described_class.new.provider_class }

    it { is_expected.to eq(Adyen::API) }
  end

  describe 'method_type' do
    subject { described_class.new.method_type }

    it { is_expected.to eq("adyen_encrypted_cc") }
  end

  describe 'payment source class' do
    subject { described_class.new.payment_source_class }

    it { is_expected.to eq(Spree::CreditCard) }
  end

  describe 'cse_token' do
    subject { described_class.new.cse_token }

    context "with no preference set" do
      before { ENV["ADYEN_CSE_TOKEN"] = nil }

      it { is_expected.to eq(nil) }

      context "with an environment key set" do
        before { ENV["ADYEN_CSE_TOKEN"] = "SUPERTOKEN" }
        after { ENV["ADYEN_CSE_TOKEN"] = nil}

        it { is_expected.to eq("SUPERTOKEN") }
      end
    end

    context "with a preference set" do
      subject do
        described_class.new(preferred_cse_token: "SOMETHING").cse_token
      end

      it { is_expected.to eq("SOMETHING") }
    end
  end

  describe 'api_username' do
    subject { described_class.new.api_username }

    context "with no preference set" do
      before { ENV["ADYEN_API_USERNAME"] = nil }

      it { is_expected.to eq(nil) }

      context "with an environment key set" do
        before { ENV["ADYEN_API_USERNAME"] = "SUPERTOKEN" }
        after { ENV["ADYEN_API_USERNAME"] = nil}

        it { is_expected.to eq("SUPERTOKEN") }
      end
    end

    context "with a preference set" do
      subject do
        described_class.new(preferred_api_username: "SOMETHING").api_username
      end

      it { is_expected.to eq("SOMETHING") }
    end
  end

  describe 'api_password' do
    subject { described_class.new.api_password }

    context "with no preference set" do
      before { ENV["ADYEN_API_PASSWORD"] = nil }

      it { is_expected.to eq(nil) }

      context "with an environment key set" do
        before { ENV["ADYEN_API_PASSWORD"] = "SUPERPASSWORD" }
        after { ENV["ADYEN_API_PASSWORD"] = nil}

        it { is_expected.to eq("SUPERPASSWORD") }
      end
    end

    context "with a preference set" do
      subject do
        described_class.new(preferred_api_password: "SECRETPASSWORD").api_password
      end

      it { is_expected.to eq("SECRETPASSWORD") }
    end
  end
end
