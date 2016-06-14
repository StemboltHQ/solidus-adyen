require "spec_helper"

RSpec.describe Spree::Adyen::HppsController, type: :controller do
  describe "GET directory" do
    let(:order) { create :order }
    let(:payment_method) { create :hpp_gateway }
    let(:parsed_directory_response) { [{
      name: "American Express",
      brandCode: "amex",
      payment_url: "www.test-payment-url.com/amex"}] }

    before do
      allow(Spree::Adyen::HPP).to receive(:payment_methods_from_directory).
        with(order, payment_method).
        and_return(parsed_directory_response)
    end

    context "html response" do
      subject {
        get :directory,
        order_id: order.id,
        payment_method_id: payment_method.id }

      it { is_expected.to have_http_status :ok }
      it { is_expected.to render_template "directory" }
    end

    context "json response" do
      subject {
        get :directory,
        order_id: order.id,
        payment_method_id: payment_method.id,
        format: :json }

      it { is_expected.to have_http_status :ok }

      it "renders a json response" do
        subject
        expect(response.body).to eq parsed_directory_response.to_json
      end
    end
  end
end
