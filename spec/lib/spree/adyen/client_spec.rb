require 'spec_helper'

describe Spree::Adyen::Client do
  shared_examples "client API request" do |method, action|
    let(:gateway) { double("gateway", api_username: "batman", api_password: "gotham") }
    let(:client) { instance_double("Adyen::REST::Client", close: true) }
    let(:mock_params) { { peter: "parker" } }
    let(:response) { double("Mock Response", success?: true) }

    subject { described_class.new(gateway).public_send(method, mock_params) }

    before do
      allow_any_instance_of(Spree::Adyen::Client).
        to receive(:client).
        and_return(client)
      allow(client).to receive(action).and_return(response)
    end

    it "calls the correct API action with the provided parameters" do
      expect(client).to receive(action).with(peter: "parker")
      subject
    end

    it "returns a Spree::Adyen::ApiResponse" do
      expect(subject).to be_a Spree::Adyen::ApiResponse
    end

    context "when the request succeeds" do
      it "has a successful response status" do
        expect(subject.success?).to eq true
      end

      it "includes the original response" do
        expect(subject.gateway_response).to eq response
      end
    end

    context "when the request fails" do
      let(:response) { double("Mock Response", success?: false) }

      it "has a failed response status" do
        expect(subject.success?).to eq false
      end

      it "includes the original response" do
        expect(subject.gateway_response).to eq response
      end
    end

    context "when the request raises an adyen response error" do
      let(:error) { Adyen::REST::ResponseError.new("BOOM") }
      before do
        allow(client).to receive(action).
          and_raise(error)
      end

      it "has a failed response status" do
        expect(subject.success?).to eq false
      end

      it "includes the original error response" do
        expect(subject.gateway_response).to eq error
      end
    end
  end

  describe "#authorise_recurring_payment" do
    include_examples "client API request",
      :authorise_recurring_payment, :authorise_recurring_payment
  end

  describe "#reauthorise_recurring_payment" do
    include_examples "client API request",
      :reauthorise_recurring_payment, :reauthorise_recurring_payment
  end

  describe "#capture_payment" do
    include_examples "client API request", :capture_payment, :capture_payment
  end

  describe "#refund_payment" do
    include_examples "client API request", :refund_payment, :refund_payment
  end

  describe "#cancel_payment" do
    include_examples "client API request", :cancel_payment, :cancel_or_refund_payment
  end

  describe "#list_recurring_details" do
    include_examples "client API request", :list_recurring_details, :list_recurring_details
  end
end
