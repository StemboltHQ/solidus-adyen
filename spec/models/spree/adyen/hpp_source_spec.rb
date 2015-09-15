require 'spec_helper'

RSpec.describe Spree::Adyen::HppSource do
  it { is_expected.to belong_to(:order) }
  it { is_expected.to have_one(:payment) }
  it { is_expected.to have_many(:notifications) }

  shared_context "an auth notification was received" do
    let!(:auth) { create :notification, :auth, order: order }
    let!(:payment) { create :hpp_payment, source: source, order: order }
    let(:source) { create :hpp_source, order: order }
    let(:order) { create :order }
  end

  shared_context "a capture notification was received" do
    include_context "an auth notification was received"
    let!(:capture) { create :notification, :capture, order: order, prev: auth }
  end

  context "most recent notification was" do
    subject { source }

    context "auth" do
      include_context "an auth notification was received"
      it { expect(subject.can_capture?).to be true }
      it { expect(subject.can_void?).to be true }
      it { expect(subject.can_refund?).to be false }
    end

    context "capture" do
      include_context "a capture notification was received"
      it { expect(subject.can_capture?).to be false }
      it { expect(subject.can_void?).to be false }
      it { expect(subject.can_refund?).to be true }
    end

    context "refund" do
    end
  end
end
