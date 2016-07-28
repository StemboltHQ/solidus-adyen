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

  describe 'cse_library_location' do
    subject { described_class.new.cse_library_location }

    context "with no preference set" do
      before { ENV["ADYEN_CSE_LIBRARY_LOCATION"] = nil }

      it { is_expected.to eq(nil) }

      context "with an environment key set" do
        before { ENV["ADYEN_CSE_LIBRARY_LOCATION"] = "SUPERTOKEN" }
        after { ENV["ADYEN_CSE_LIBRARY_LOCATION"] = nil}

        it { is_expected.to eq("SUPERTOKEN") }
      end
    end

    context "with a preference set" do
      subject do
        described_class.new(preferred_cse_library_location: "SOMETHING").cse_library_location
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

  describe 'payment_profiles_supported?' do
    subject { described_class.new.payment_profiles_supported? }
    it { is_expected.to be false }
  end

  describe 'authorize' do
    subject { gateway.authorize(2000, card, gateway_options) }
    let(:gateway) { described_class.new }
    let(:gateway_options) do
      {
        order_id: "R423936067-5D5ZHURX",
        email: "spree@example.com",
        customer_id: 1,
        currency: "USD",
        ip: "1.2.3.4"
      }
    end
    let(:card) { stub_model(Spree::CreditCard, gateway_customer_profile_id: "CARDIDATADYEN") }

    it { is_expected.to be_a(ActiveMerchant::Billing::Response) }
    it { is_expected.to be_success }

    it "tells the user it's a dummy response" do
      expect(subject.message).to eq("dummy authorization response")
    end
  end

  context "payment modifying actions" do
    let(:gateway) { described_class.new }

    include_context "mock adyen api", success: true, klass: described_class

    shared_examples "delayed gateway action" do
      context "when the action succeeds" do
        include_context "mock adyen api", success: true, klass: described_class

        it { is_expected.to be_a ::ActiveMerchant::Billing::Response }

        it "returns the orginal psp ref as an authorization" do
          expect(subject.authorization).to eq "9999"
        end
      end

      context "when the action fails" do
        include_context(
          "mock adyen api",
          success: false,
          fault_message: "Should fail",
          klass: described_class
        )

        it "has a response that contains the failure message" do
          expect(subject.success?).to be false
          expect(subject.message).to eq "Should fail"
        end
      end
    end

    describe ".capture" do
      subject { gateway.capture(2000, "9999", currency: "EUR") }
      include_examples "delayed gateway action"
    end

    describe ".credit" do
      subject { gateway.credit(2000, "9999", currency: "EUR") }
      include_examples "delayed gateway action"
    end

    describe ".cancel" do
      subject { gateway.cancel("9999") }
      include_examples "delayed gateway action"
    end
  end
end
