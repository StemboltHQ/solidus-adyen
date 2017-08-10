require 'spec_helper'

describe Spree::Gateway::AdyenCreditCard do
  it { is_expected.to be_a(Spree::Gateway) }

  describe 'provider_class' do
    subject { described_class.new.provider_class }

    it { is_expected.to eq(Adyen::REST) }
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

  describe '#authorize' do
    include_context("mock adyen client", success: true, psp_reference: "123ABC")

    subject { gateway.authorize(2000, card, gateway_options) }

    let(:gateway) { described_class.new }
    let(:card) { create(:credit_card, adyen_token: "ADYENTESTTOKEN") }
    let(:payment) { create(:payment, source: card, payment_method: gateway) }
    let(:gateway_options) do
      {
        order_id: payment.send(:gateway_order_id),
        email: "spree@example.com",
        customer_id: 1,
        currency: "USD",
        ip: "1.2.3.4"
      }
    end

    context "reusing an existing source" do
      let(:card) { create(:credit_card, gateway_customer_profile_id: "TESTACCOUNT") }

      it { is_expected.to be_a ::ActiveMerchant::Billing::Response }

      it "sets the PSP reference as the authorization" do
        expect(subject.authorization).to eq("123ABC")
      end

      it "calls the reauthorise existing endpoint" do
        expect(client).to receive(:reauthorise_recurring_payment)
        subject
      end

      context "action succeeds" do
        it { is_expected.to be_success }

      end

      context "action fails" do
        include_context("mock adyen client", success: false, fault_message: "No good!")

        it { is_expected.not_to be_success }

        it "returns the error message from Adyen" do
          expect(subject.message).to eq("No good!")
        end
      end
    end

    context "paying with a new card" do
      it "makes a new authorisation request" do
        expect(client).to receive(:authorise_recurring_payment)
        subject
      end
    end

    context "no token or profile present" do
      let(:card) { create(:credit_card) }

      it "raises an error" do
        expect { subject }.to raise_error(
          Spree::Gateway::AdyenCreditCard::MissingTokenError,
          I18n.t(:missing_token_error, scope: 'solidus-adyen')
        )
      end
    end
  end

  context "payment modifying actions" do
    let!(:payment) { create(:payment, response_code: "9999") }
    let(:preferences) { { store_merchant_account_map: { payment.order.store.code => "myadyenaccount" } } }
    let(:gateway) { described_class.new(preferences: preferences) }

    shared_examples "delayed gateway action" do |action|
      context "when the action succeeds" do
        include_context "mock adyen client", success: true

        it { is_expected.to be_a ::ActiveMerchant::Billing::Response }

        it "returns the orginal psp ref as an authorization" do
          expect(subject.authorization).to eq "9999"
        end

        it "includes the correct merchant account in the request" do
          expect(client).to receive("#{action}_payment").
            with(hash_including(merchant_account: "myadyenaccount"))
          subject
        end
      end

      context "when the action fails" do
        include_context(
          "mock adyen client",
          success: false,
          fault_message: "Something went wrong",
        )

        it "reports a failed status" do
          expect(subject.success?).to be false
        end

        it "returns the error message" do
          expect(subject.message).to eq "Something went wrong"
        end
      end
    end

    describe ".capture" do
      subject { gateway.capture(2000, "9999", currency: "EUR") }
      include_examples "delayed gateway action", "capture"
    end

    describe ".credit" do
      subject { gateway.credit(2000, "9999", currency: "EUR") }
      include_examples "delayed gateway action", "refund"
    end

    describe ".cancel" do
      subject { gateway.cancel("9999") }
      include_examples "delayed gateway action", "cancel"
    end
  end
end
