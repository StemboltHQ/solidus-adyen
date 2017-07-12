require 'spec_helper'

describe Spree::Adyen::AccountLocator do
  let(:account_locator) { described_class.new({ "test" => "OTHER_ACCOUNT" }, "DEFAULT_ACCOUNT") }

  describe "#by_reference" do
    let(:store) { create(:store, code: "test") }
    let(:order) { build(:order, store: store) }
    let!(:payment) { create(:payment, order: order, response_code: "AUTH") }

    subject { account_locator.by_reference("AUTH") }
    # Solidus 1.3+ requires orders to belong to a store, so I need to skip
    # validations to test this behaviour
    before { order.save(validate: false) }

    context "the payment's order belongs to a store" do
      it { is_expected.to eq "OTHER_ACCOUNT" }
    end

    context "the payment's order does not belong to a store" do
      let(:store) { nil }
      it { is_expected.to eq "DEFAULT_ACCOUNT" }
    end
  end

  describe "#by_order" do
    let(:store) { build_stubbed(:store, code: "test") }
    let(:order) { build_stubbed(:order, store: store) }

    subject { account_locator.by_order(order) }

    context "order belongs to a store" do
      it { is_expected.to eq "OTHER_ACCOUNT" }
    end

    context "order does not belong to a store" do
      let(:store) { nil }
      it { is_expected.to eq "DEFAULT_ACCOUNT" }
    end
  end

  describe "#by_store_code" do
    subject { account_locator.by_store_code(code) }

    context "other merchant account set for the store" do
      let(:code) { "test" }
      it { is_expected.to eq "OTHER_ACCOUNT" }
    end

    context "no account set for the store" do
      let(:code) { nil }
      it { is_expected.to eq "DEFAULT_ACCOUNT" }
    end
  end
end
