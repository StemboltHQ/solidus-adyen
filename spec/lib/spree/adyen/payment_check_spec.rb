require 'spec_helper'

describe Spree::Adyen::PaymentCheck do
  describe ".hpp_payment?" do
    subject { payment.hpp_payment? }

    context "when it is an hpp payment" do
      let(:payment) { build_stubbed :hpp_payment }
      it { is_expected.to be true }
    end

    context "when it is not an hpp payment" do
      let(:payment) { build_stubbed :adyen_cc_payment }
      it { is_expected.to be false }
    end
  end

  describe ".adyen_cc_payment?" do
    subject { payment.adyen_cc_payment? }

    context "when it is an hpp payment" do
      let(:payment) { build_stubbed :adyen_cc_payment }
      it { is_expected.to be true }
    end

    context "when it is not an hpp payment" do
      let(:payment) { build_stubbed :hpp_payment }
      it { is_expected.to be false }
    end
  end
end
