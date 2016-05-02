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
        expect(message).to eq("The credit card data you have entered is invalid.")
      end
    end

    context "and the form is filled out formally correctly, but with an invalid card" do
      it "provides a meaningful error message" do
        VCR.use_cassette "Credit Card not accepted", record: :new_episodes do
          choose('Adyen Credit Card')
          fill_in("card_number", with: "4111111111111111")
          fill_in("expiry_month", with: "05")
          fill_in("expiry_year", with: "2019")
          fill_in("verification_value", with: "747")
          click_button('Save and Continue')
          expect(page).to have_content("The credit card data you have entered is invalid.")
        end
      end
    end

    context "and the form is filled out correctly" do
      context "with an authorization on complete" do
        it "correctly processes an authorization" do
          VCR.use_cassette "Credit Card Authorization Process", record: :new_episodes do
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

      context "with an purchase on complete" do
        before do
          Spree::Config[:auto_capture] = true
        end

        after do
          Spree::Config[:auto_capture] = false
        end

        it "correctly processes an purchase" do
          VCR.use_cassette "Credit Card Purchase Process", record: :new_episodes do
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
    end
  end

  context "when the adyen gateway is not selected", js: true, truncation: true do
    context "and the form is not filled out" do
      it "submits the data from the other gateway" do
        choose('Credit Card')
        click_button('Save and Continue')
        expect(page).to have_content("Number can't be blank")
      end
    end
  end
end
