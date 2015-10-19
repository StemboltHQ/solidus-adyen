require 'spec_helper'

module Spree
  describe Gateway::AdyenHPP do
    describe ".capture" do
      let(:response) do
        instance_double(
          ::Adyen::API::PaymentService::CaptureResponse,
          success?: true,
          params:
          { psp_reference: "1234",
            response: "[capture-received]"
          }
        )
      end

      it "makes an api call" do
        expect(subject.provider_class).
          to receive(:capture_payment).
          and_return(response)

        expect(subject.capture(2000, "1234", currency: "CAD")).
          to be_a ::ActiveMerchant::Billing::Response
      end
    end

    context "comply with spree payment/processing api" do
      context "void" do
        it "makes response.authorization returns the psp reference" do
          response = double('Response', success?: true, psp_reference: "huhu")
          subject.stub_chain(:provider, cancel_payment: response)

          expect(subject.void("huhu").authorization).to eq "huhu"
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
