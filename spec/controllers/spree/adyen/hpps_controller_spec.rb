require "spec_helper"

RSpec.describe Spree::Adyen::HppsController, type: :controller do
  describe 'GET directory' do
    subject {
      get :directory,
      order_id: order.id,
      payment_method_id: payment_method.id }

    let(:order) { create :order }
    let(:payment_method) { create :hpp_gateway }

    before do
      allow(Spree::Adyen::Form).to receive(:payment_methods_from_directory).
        with(order, payment_method).
        and_return([{
          'name' => 'American Express',
          'brandCode' => 'amex'}])
    end

    it { is_expected.to have_http_status :ok }
    it { is_expected.to render_template 'directory' }
  end
end
