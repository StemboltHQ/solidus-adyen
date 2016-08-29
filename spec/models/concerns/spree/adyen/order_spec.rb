require "spec_helper"

RSpec.describe Spree::Order do
  include_context "mock adyen client", success: true

  describe "requires_manual_refund?" do
    subject { order.requires_manual_refund? }

    let!(:order) { create :order_ready_to_ship }

    it { is_expected.to be false }

    context "when it is cancelled and has a payment that much be manually refunded" do
      let!(:payment) { create :hpp_payment, order: order, source: source }
      let(:source) { create :hpp_source, :sofort, order: order }

      before { order.cancel! }

      it { is_expected.to be true }
    end
  end
end
