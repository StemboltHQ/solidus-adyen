require 'spec_helper'

describe Spree::Adyen::Invoice do
  describe "#request_params" do
    let(:address) { create(:address) }
    let(:tax_rate_country) { address.country }
    let(:tax_category) { create(:tax_category) }
    let!(:zone) { create(:zone, name: "Country Zone", default_tax: true, countries: [tax_rate_country]) }
    let!(:rate) { create(:tax_rate, tax_category: tax_category, amount: 0.19, included_in_price: true, zone: zone) }
    let(:order) do
      create(
        :order_with_line_items,
        number: "R9999999",
        line_items_attributes: [
          { price: 70, quantity: quantity, tax_category: tax_category }
        ],
        ship_address: address
      )
    end

    describe "#request_params" do
      subject { described_class.new(order).request_params }
      let(:quantity) { 1 }

      it "generates the correct params" do
        expect(subject).to include(
          openinvoicedata: {
            number_of_lines: 1,
            refund_description: "Refund for R9999999",
            "line1" => {
              currency_code: "USD",
              description: anything,
              item_amount: 5882,
              item_vat_amount: 1118,
              item_vat_percentage: 1900,
              line_reference: 1,
              number_of_items: 1,
              vat_category: "High"
            }
          }
        )
      end

      context "line item has quantity 1" do
        it "has the correct item and VAT amount" do
          invoice_line = subject[:openinvoicedata]["line1"]
          expect(invoice_line[:item_amount]).to eq 5882
          expect(invoice_line[:item_vat_amount]).to eq 1118
        end
      end

      # Before fixing rounding errors, a quantity of 2 would produce an item VAT
      # amount of 1117, making the item total 6999 instead of 7000
      context "line item has quantity 2" do
        let(:quantity) { 2 }

        it "has the correct item and VAT amount" do
          invoice_line = subject[:openinvoicedata]["line1"]
          expect(invoice_line[:item_amount]).to eq 5882
          expect(invoice_line[:item_vat_amount]).to eq 1118
        end
      end
    end
  end
end
