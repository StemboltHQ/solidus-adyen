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
      it "disables the submit button" do
        choose('Adyen Credit Card')

        expect(page).to have_selector('#checkout_form_payment input[type="submit"][disabled]')
      end
    end
  end
end
