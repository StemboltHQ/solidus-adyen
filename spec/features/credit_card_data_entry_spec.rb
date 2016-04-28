require 'spec_helper'
require 'spree/testing_support/order_walkthrough'

shared_context "checkout setup" do

  let!(:adyen_cc_gateway) { create(:adyen_cc_gateway) }
  let!(:normal_cc_gateway) { create(:credit_card_payment_method) }

  before(:each) do
    order = OrderWalkthrough.up_to(:delivery)

    user = create(:user)
    order.user = user
    order.update!

    allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)
    allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: user)

    visit spree.checkout_state_path(:delivery)
    click_button "Save and Continue"
  end
end

describe "Entering Credit Card Data" do
  include_context 'checkout setup'

  it "shows the adyen gateway as an option" do
    expect(page).to have_content("Adyen Credit Card")
  end

  context "when the adyen gateway is selected", js: true, truncation: true do
    context "and the form is not filled out" do
      it "displays an alert on submit and validates the form" do
        choose('Adyen Credit Card')
        message = accept_prompt do
          click_button('Save and Continue')
        end
        expect(message).to eq('Your credit card data is invalid.')
      end
    end

    context "and the form is filled out correctly" do
      it "submits encrypted data but no actual data" do
        choose('Adyen Credit Card')
        fill_in("card_number", with: "4111111111111111")
        fill_in("expiry_month", with: "06")
        fill_in("expiry_year", with: "2016")
        fill_in("verification_value", with: "737")
        click_button('Save and Continue')
        click_button('Place Order')
        expect(page).to have_content("Your order has been processed successfully")
      end
    end
  end

  context "when the adyen gateway is not selected", js: true, truncation: true do
    context "and the form is not filled out" do
      it "displays an alert on submit and validates the form" do
        choose('Credit Card')
        click_button('Save and Continue')
        expect(page).to have_content("Number can't be blank")
      end
    end
  end
end
