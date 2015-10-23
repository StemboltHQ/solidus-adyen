require 'spec_helper'

RSpec.describe Spree::Adyen::HppSource do
  it { is_expected.to belong_to(:order) }
  it { is_expected.to have_one(:payment) }
  it { is_expected.to have_many(:notifications) }

  context "when payment has been authorized for capture" do
    let(:hpp_source) do
      create :hpp_source,
        psp_reference: "999999999",
        merchant_reference: "R11111111"
    end

    let!(:notification) do
      create(
        :notification,
        :auth,
        operations: "CAPTURE,REFUND",
        psp_reference: "999999999",
        merchant_reference: "R11111111",
        processed: true
      )
    end

    it { expect(hpp_source.notifications.count).to eq 1 }
    it { expect(hpp_source.actions).
         to eq %w{adyen_hpp_capture adyen_hpp_refund} }
  end
end
