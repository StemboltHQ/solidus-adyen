require "spec_helper"

RSpec.describe Spree::Api::AdyenController, type: :controller do
  render_views

  let(:order) { create :order }
  let(:payment_method) { create :hpp_gateway }
  let(:parsed_directory_response) { [{
        name: "American Express",
        brandCode: "amex",
        payment_url: "www.test-payment-url.com/amex"}] }

  let(:params) do
    { order_id: order.to_param,
      payment_method_id: payment_method.id }
  end

  before do
    allow_any_instance_of(Spree::Ability).to receive(:can?).and_return(true)

    stub_authentication!

    allow(Spree::Order).to receive(:find_by!).
      with(number: order.number).
      and_return(order)

    allow(Spree::Adyen::HPP).to receive(:payment_methods_from_directory).
      with(order, payment_method).
      and_return(parsed_directory_response)
  end

  subject { get action, params }

  context "hpp" do
    let(:action) { "hpp" }

    before { subject }

    it { expect(response.status).to eq(200) }

    it { expect(response.body).to include("www.test-payment-url.com/amex") }
  end
end