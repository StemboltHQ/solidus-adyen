require 'spec_helper'

module Spree
  describe Gateway::AdyenHPP do
    context "comply with spree payment/processing api" do
      context "void" do
        it "makes response.authorization returns the psp reference" do
          response = double('Response', success?: true, psp_reference: "huhu")
          subject.stub_chain(:provider, cancel_payment: response)

          expect(subject.void("huhu").authorization).to eq "huhu"
        end
      end

      context "capture" do
        it "makes response.authorization returns the psp reference" do
          response = double('Response', success?: true, psp_reference: "huhu")
          subject.stub_chain(:provider, capture_payment: response)

          result = subject.capture(30000, "huhu")
          expect(result.authorization).to be nil
          expect(result.avs_result).to eq({})
          expect(result.cvv_result).to eq({})
        end
      end
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
