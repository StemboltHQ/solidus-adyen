require 'spec_helper'

RSpec.describe Spree::Adyen::HppSource do
  it { is_expected.to belong_to(:order) }
  it { is_expected.to have_one(:payment) }
  it { is_expected.to have_many(:notifications) }

  let(:hpp_source) do
    create :hpp_source,
      psp_reference: "999999999",
      merchant_reference: "R11111111"
  end

  describe ".actions" do
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

    context "when it has not auth notification" do
      let!(:notification) { nil }
      it { expect(hpp_source.actions).to eq [] }
    end
  end

  describe ".can_adyen_hpp_capture?" do
    subject { hpp_source.can_adyen_hpp_capture? payment }
    let!(:payment) { create :payment, amount: 10.0 }

    it { is_expected.to be true }

    context "when there is no outstanding balance" do
      before do
        payment.
          capture_events.
          create! amount: ::Money.new(1000, "EUR").to_f
      end
      it { is_expected.to be false }
    end
  end
end
