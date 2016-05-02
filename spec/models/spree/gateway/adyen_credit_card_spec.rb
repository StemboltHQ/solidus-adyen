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
    it { is_expected.to be true }
  end

  describe 'create_profile' do
    let(:order) { build_stubbed(:order)}
    let(:gateway) { described_class.new }
    let(:payment) { build_stubbed(:payment, source: card, order: order) }

    subject { gateway.create_profile(payment) }

    context "when the card already has a customer profile" do
      let(:card) { build_stubbed(:credit_card, gateway_customer_profile_id: "APROFILE") }

      it "does no calls and returns nil" do
        expect(gateway.provider).not_to receive(:authorize_payment)
        expect(subject).to be nil
      end
    end

    context "when the card has no customer profile yet" do
      let(:order) do
        build_stubbed(
          :order,
          user_id: 5565,
          email: "hello@mydomain.com",
          last_ip_address: "1.2.3.4",
          number: "MYORDERNUMBER",
          currency: "RUB"
        )
      end

      let(:card) { build_stubbed(:credit_card, number: nil, encrypted_data: "HARDENCRYPTEDDATA") }
      let(:card_list) { Adyen::API::RecurringService::ListResponse.new(nil) }
      it "authorizes a payment with zero dollars in the correct currency" do
        expect(gateway.provider).to receive(:authorise_payment).with(
          5565,
          { value: 0, currency: "RUB" },
          { reference: 5565, email: "hello@mydomain.com", ip: "1.2.3.4", statement: "MYORDERNUMBER"},
          { encrypted: { json: "HARDENCRYPTEDDATA" } },
          true
        ).and_return(OpenStruct.new(success?: true))
        expect(card_list).to receive(:details).and_return([])
        expect(gateway.provider).to receive(:list_recurring_details).with(5565).and_return(card_list)
        subject
      end

      context "and the card is valid" do
        let(:card) { create(:credit_card, last_digits: "", number: "", encrypted_data: "OHSOENCRYPTED") }

        let(:registered_card_details) do
          {
            recurring_detail_reference: "CARDIDATADYEN",
            variant: "visa",
            card: {
              expiry_date: Date.new(2015, 06, 30),
              holder_name: "Johnny Doe",
              number: "1111"
            }
          }
        end

        before do
          expect(gateway.provider).to receive(:authorise_payment).and_return(OpenStruct.new(success?: true))
          expect(gateway.provider).to receive(:list_recurring_details).with(5565).and_return(card_list)
          expect(card_list).to receive(:details).and_return([registered_card_details])
        end

        it "it populates the credit card object with a customer profile" do
          expect { subject }.to change { card.gateway_customer_profile_id }.to("CARDIDATADYEN")
        end

        it "populates the credit card object with a credit card type" do
          expect { subject }.to change { card.cc_type }.to("visa")
        end

        it "populates the credit card object with the last digits" do
          expect { subject }.to change { card.last_digits }.to("1111")
        end

        it "populates the credit card with a month" do
          expect { subject }.to change { card.month }.to("06")
        end

        it "populates the credit card with a year" do
          expect { subject }.to change { card.year }.to("2015")
        end

        it "populates the credit card with a name" do
          expect { subject }.to change { card.name }.to("Johnny Doe")
        end
      end

      context "and the card is submitted unencrypted" do
        let(:card) { build(:credit_card, number: "4111 1111 1111 1111") }
        let(:payment) { build(:payment, source: card) }

        subject { gateway.create_profile(payment) }

        it "raises an error" do
          expect { subject }.to raise_error(described_class::ClearTextCardNumberError)
        end
      end
    end
  end

  describe 'authorize' do
    let(:gateway) { described_class.new }
    let(:adyen_response) { Adyen::API::PaymentService::AuthorisationResponse.new(nil) }
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

    before do
      expect(adyen_response).to receive(:success?).at_least(:once) { true }
      expect(adyen_response).to receive(:params).at_least(:once) { adyen_params }
      expect(adyen_response).to receive(:psp_reference) { adyen_params[:psp_reference] }
    end

    context "when payment is successful" do
      let(:adyen_params) do
        {
          psp_reference: "BEAUTIFULREFERENCE",
          result_code: "Authorised",
          auth_code: "ISSUER_AUTH",
          additional_data: {},
          refusal_reason: ""
        }
      end

      it "calls the Adyen service with the right options and returns the correct object" do
        expect(gateway.provider).to receive(:authorise_recurring_payment).with(
          "R423936067-5D5ZHURX",
          { value: 2000, currency: "USD" },
          { reference: 1, email: "spree@example.com", ip: "1.2.3.4", statement: "R423936067-5D5ZHURX" },
          "CARDIDATADYEN",
          nil,
          false
        ).and_return(adyen_response)

        response = gateway.authorize(2000, card, gateway_options)
        expect(response.success?).to be true
        expect(response.message).to eq(
          JSON.pretty_generate({
            "psp_reference" => "BEAUTIFULREFERENCE",
            "result_code" => "Authorised",
            "auth_code" => "ISSUER_AUTH",
            "additional_data" => {},
            "refusal_reason" => ""
          })
        )
        expect(response.params).to eq(
          {
            "psp_reference" => "BEAUTIFULREFERENCE",
            "result_code" => "Authorised",
            "auth_code" => "ISSUER_AUTH",
            "additional_data" => {},
            "refusal_reason" => ""
          }
        )
        expect(response.authorization).to eq("BEAUTIFULREFERENCE")
        expect(response.error_code).to be_nil
      end
    end
  end

  describe 'purchase' do
    let(:gateway) { described_class.new }
    let(:adyen_response) { Adyen::API::PaymentService::AuthorisationResponse.new(nil) }
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

    before do
      expect(adyen_response).to receive(:success?).at_least(:once) { true }
      expect(adyen_response).to receive(:params).at_least(:once) { adyen_params }
      expect(adyen_response).to receive(:psp_reference) { adyen_params[:psp_reference] }
    end

    context "when payment is successful" do
      let(:adyen_params) do
        {
          psp_reference: "BEAUTIFULREFERENCE",
          result_code: "Authorised",
          auth_code: "ISSUER_AUTH",
          additional_data: {},
          refusal_reason: ""
        }
      end

      it "calls the Adyen service with the right options and returns the correct object" do
        expect(gateway.provider).to receive(:authorise_recurring_payment).with(
          "R423936067-5D5ZHURX",
          { value: 2000, currency: "USD" },
          { reference: 1, email: "spree@example.com", ip: "1.2.3.4", statement: "R423936067-5D5ZHURX" },
          "CARDIDATADYEN",
          nil,
          true
        ).and_return(adyen_response)

        response = gateway.purchase(2000, card, gateway_options)
        expect(response.success?).to be true
        expect(response.message).to eq(
          JSON.pretty_generate({
            "psp_reference" => "BEAUTIFULREFERENCE",
            "result_code" => "Authorised",
            "auth_code" => "ISSUER_AUTH",
            "additional_data" => {},
            "refusal_reason" => ""
          })
        )
        expect(response.params).to eq(
          {
            "psp_reference" => "BEAUTIFULREFERENCE",
            "result_code" => "Authorised",
            "auth_code" => "ISSUER_AUTH",
            "additional_data" => {},
            "refusal_reason" => ""
          }
        )
        expect(response.authorization).to eq("BEAUTIFULREFERENCE")
        expect(response.error_code).to be nil
      end
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
