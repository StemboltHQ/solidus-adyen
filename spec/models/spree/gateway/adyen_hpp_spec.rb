require "spec_helper"
require "support/shared_contexts/mock_adyen_api"

module Spree
  describe Gateway::AdyenHPP do
    let(:hpp_source) { create :hpp_source, psp_reference: "9999" }
    let(:gateway) { described_class.new }

    include_context "mock adyen api", success: true

    describe ".capture" do
      subject { gateway.capture(2000, "9999", currency: "CAD") }

      it "makes an api call the returns the orginal psp ref as an authorization" do
        expect(subject).to be_a ::ActiveMerchant::Billing::Response

        expect(subject.authorization).to eq "9999"
      end

      context "when the action fails" do
        include_context(
          "mock adyen api",
          success: false,
          fault_message: "Should fail")

        it "has a response that contains the failure message" do
          expect(subject.success?).to be false
          expect(subject.message).to eq "Should fail"
        end
      end
    end

    describe ".authorize" do
      subject { gateway.authorize 2000, hpp_source, currency: "CAD" }
      it { is_expected.to be_a ActiveMerchant::Billing::Response }
    end

    context "calculate ship_before_date" do
      let(:test_time) { Time.local(2015, 9, 1, 12, 0, 0) }

      context "days_to_ship has been set" do
        it "returns tomorrow" do
          Timecop.freeze(test_time) do
            expect(subject.ship_before_date).to eq  Time.local(2015, 9, 2, 12, 0, 0)
          end
        end
      end

      context "days_to_ship has not been set" do
        it "returns date days_to_ship in the future" do
          subject.preferred_days_to_ship = 3
          Timecop.freeze(test_time) do
            expect(subject.ship_before_date).to eq  Time.local(2015, 9, 4, 12, 0, 0)
          end
        end
      end
    end
  end
end
