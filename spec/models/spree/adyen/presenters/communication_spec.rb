require "spec_helper"

module Spree
  module Adyen
    module Presenters
      RSpec.describe Communication do
        let!(:source) { payment.source }
        let!(:payment) { create :hpp_payment }
        let!(:notification) { create :notification, :auth, payment: payment }

        let!(:log_entry) do
          payment.send(
            :record_response,
            OpenStruct.new(success?: true, message: "sup")
          )
        end

        describe "#from_source" do
          subject { described_class.from_source source }

          it "builds a collection of presenters that all implement the interface" do
            expect(subject).
              to be_an(Array).
              and all(
                be_a(Communications::Base).
                and respond_to(:success?).
                and respond_to(:processed?).
                and respond_to(:inbound?).
                and respond_to(:fields))
          end
        end

        describe "#build" do
          subject { described_class.build(record) }

          [[:log_entry, Communications::LogEntry],
           [:source, Communications::HppSource],
           [:notification, Communications::AdyenNotification]
          ].each do |assigned_name, presenter|
            context "when presented object is a #{assigned_name.to_s.humanize}" do
              let(:record) { send assigned_name }

              it "creates a presenter using #{presenter}" do
                is_expected.to be_a presenter
              end
            end
          end

          context "when a presenter cannot be found" do
            let(:record) { Object.new }

            it "fails" do
              expect { subject }.to raise_error(
                RuntimeError,
                /Couldn't map to a communication type/)
            end
          end
        end
      end
    end
  end
end
