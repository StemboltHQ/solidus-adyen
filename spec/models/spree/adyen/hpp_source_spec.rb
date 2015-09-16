require 'spec_helper'

RSpec.describe Spree::Adyen::HppSource do
  it { is_expected.to belong_to(:order) }
  it { is_expected.to have_one(:payment) }
  it { is_expected.to have_many(:notifications) }

  context "most recent notification was" do
    subject { source }

    let!(:payment) { create :hpp_payment, source: source, order: order }
    let(:source) { create :hpp_source, order: order }
    let(:order) { create :order }

    shared_context "an auth notification was received" do
      let!(:auth) { create :notification, :auth, order: order }
    end

    shared_context "a capture notification was received" do
      include_context "an auth notification was received"
      let!(:capture) { create :notification, :capture, order: order,
                       prev: auth }
    end

    context "no response from adyen yet" do
      it { expect(subject.can_capture?(payment)).to be false }
      it { expect(subject.can_void?(payment)).to be false }
      it { expect(subject.can_credit?(payment)).to be false }
    end

    context "auth" do
      include_context "an auth notification was received"
      it { expect(subject.can_capture?(payment)).to be true }
      it { expect(subject.can_void?(payment)).to be true }
      it { expect(subject.can_credit?(payment)).to be false }
    end

    context "capture" do
      include_context "a capture notification was received"
      it { expect(subject.can_capture?(payment)).to be false }
      it { expect(subject.can_void?(payment)).to be false }
      it { expect(subject.can_credit?(payment)).to be true }
    end

    context "refund" do
    end
  end
end
