require 'spec_helper'

describe Spree::Adyen::HPP::Params do
  let(:payment_method) { build_stubbed :ratepay_gateway }
  let(:country) { build_stubbed :country }
  let(:address) do
    build_stubbed :address,
      address1: "42 Spruce Lane",
      city: "Gotham",
      zipcode: "90210",
      country: country,
      firstname: "Wade",
      lastname: "Wilson",
      phone: "1234567890"
  end
  let(:order) do
    build_stubbed :order,
      number: "R9999999",
      user_id: 42,
      total: 2000,
      email: "batman@example.com",
      last_ip_address: "10.1.1.1",
      ship_address: address,
      bill_address: address
  end

  describe "#authorise_invoice" do
    subject { described_class.new(order, payment_method).authorise_invoice("1986-06-06") }

    it "returns the correct params" do
      expect(subject).to include({
        merchant_account: "fake_api_merchant_account",
        reference: "R9999999",
        amount: {
          currency: "USD",
          value: 200000
        },
        shopper_email: "batman@example.com",
        shopper_reference: "42",
        shopper_name: {
          first_name: "Wade",
          infix: "",
          last_name: "Wilson",
          gender: "UNKNOWN"
        },
        shopper_i_p: "10.1.1.1",
        shopper_country: "US",
        date_of_birth: "1986-06-06",
        telephone_number: "1234567890",
        delivery_address: {
          street: "Spruce Lane",
          house_number_or_name: "42",
          city: "Gotham",
          postal_code: "90210",
          country: "US",
        },
        billing_address: {
          street: "Spruce Lane",
          house_number_or_name: "42",
          city: "Gotham",
          postal_code: "90210",
          country: "US",
        },
        additional_data: {
          openinvoicedata: anything # Tested in Spree::Adyen::Invoice spec
        }
      })
    end
  end
end
