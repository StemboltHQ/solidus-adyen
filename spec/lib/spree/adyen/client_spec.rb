require 'spec_helper'

describe Spree::Adyen::Client do
  shared_examples "client API request" do |method, action|
    let(:gateway) { double("gateway", api_username: "batman", api_password: "gotham") }
    let(:client) { instance_double("Adyen::REST::Client", close: true) }
    let(:mock_params) { { peter: "parker" } }

    subject { described_class.new(gateway) }

    before { allow(subject).to receive(:client).and_return(client) }

    it "calls the correct API action with the provided parameters" do
      expect(client).to receive(action).with(peter: "parker")
      subject.public_send(method, mock_params)
    end

    context "when the request succeeds" do
      let(:response) { double("Mock Response") }
      before { allow(client).to receive(action).and_return(response) }

      it "returns the response" do
        expect(subject.public_send(method, mock_params)).to eq response
      end
    end

    context "when the request raises an adyen response error" do
      before do
        allow(client).to receive(action).
          and_raise(Adyen::REST::ResponseError.new("BOOM"))
      end

      it "raises a Spree::Core::GatewayError with the correct message" do
        expect { subject.public_send(method, mock_params) }.
          to raise_error(Spree::Core::GatewayError, "API request error: BOOM")
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
