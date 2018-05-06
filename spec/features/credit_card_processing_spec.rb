require 'spec_helper'
require 'spree/testing_support/order_walkthrough'
require 'spree/testing_support/capybara_ext'

shared_context "checkout setup" do

  let!(:adyen_cc_gateway) { create(:adyen_cc_gateway) }
  let!(:normal_cc_gateway) { create(:credit_card_payment_method) }

  before(:each) do
    order = Spree::TestingSupport::OrderWalkthrough.up_to(:delivery)

    user = create(:user)
    order.user = user
    order.recalculate

    allow_any_instance_of(Spree::CheckoutController).to receive_messages(current_order: order)
    allow_any_instance_of(Spree::CheckoutController).to receive_messages(try_spree_current_user: user)

    visit spree.checkout_state_path(:delivery)
    click_button "Save and Continue"
  end
end

shared_context "complete credit card payment" do
  include_context "checkout setup"

  before(:each) do
    Spree::Config[:auto_capture] = true

    VCR.use_cassette "Credit Card Purchase Process", record: :new_episodes do
      choose('Adyen Credit Card')
      fill_in("card_number", with: "6011601160116611")
      fill_in("expiry_month", with: "08")
      fill_in("expiry_year", with: "2018")
      fill_in("verification_value", with: "737")
      click_button('Save and Continue')
      click_button('Place Order')
    end

    Spree::Config[:auto_capture] = false
  end
end

describe "Entering Credit Card Data", js: true, truncation: true do
  include_context 'checkout setup'

  it "shows the adyen gateway as an option" do
    expect(page).to have_content("Adyen Credit Card")
  end

  context "when the adyen gateway is selected" do
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
      it "returns the user to payment after confirm with an error message" do
        VCR.use_cassette "Credit Card not accepted", record: :new_episodes do
          choose('Adyen Credit Card')
          fill_in("card_number", with: "4111111111111111")
          fill_in("expiry_month", with: "05")
          fill_in("expiry_year", with: "2019")
          fill_in("verification_value", with: "747")
          click_button('Save and Continue')
          click_button("Place Order")
          expect(page).to have_content("905 Payment details are not supported")
        end
      end
    end

    context "and the form is filled out correctly" do
      context "with an authorization on complete" do
        it "correctly processes an authorization" do
          VCR.use_cassette "Credit Card Authorization Process", record: :new_episodes do
            choose('Adyen Credit Card')
            fill_in("card_number", with: "6011601160116611")
            fill_in("expiry_month", with: "08")
            fill_in("expiry_year", with: "2018")
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
            fill_in("card_number", with: "6011601160116611")
            fill_in("expiry_month", with: "08")
            fill_in("expiry_year", with: "2018")
            fill_in("verification_value", with: "737")
            click_button('Save and Continue')
            click_button('Place Order')
            expect(page).to have_content("Your order has been processed successfully")
          end
        end
      end

      context "with a card that supports 3DS" do
        it "redirects the user to the 3DS page and completes the purchase" do
          VCR.use_cassette "3DS Credit Card Purchase", record: :new_episodes do
            choose("Adyen Credit Card")
            fill_in("card_number", with: "4212345678901237")
            fill_in("expiry_month", with: "08")
            fill_in("expiry_year", with: "2018")
            fill_in("verification_value", with: "737")
            click_button('Save and Continue')
            click_button('Place Order')
            expect(page).to have_content("Authenticate a transaction")
            fill_in("username", with: "user")
            fill_in("password", with: "password")
            click_button("Submit")
            expect(page).to have_content("Your order has been processed successfully")
          end
        end
      end
    end
  end

  context "when the adyen gateway is not selected" do
    context "and the form is not filled out" do
      it "submits the data from the other gateway" do
        choose('Credit Card')
        click_button('Save and Continue')
        expect(page).to have_content("Number can't be blank")
      end
    end
  end
end

describe "Refunding a credit card payment", js: true, truncation: true do
  stub_authorization!
  include_context "complete credit card payment"

  let!(:refund_reason) { create :refund_reason, name: "Test reason" }
  let(:order) { Spree::Order.last }
  let(:payment) { order.payments.last }
  let(:notification_params) do
    {
      "merchantAccountCode"=>"FreeRunningTechnologiesCOM",
      "eventCode"=>"CAPTURE",
      "success"=>"true",
      "pspReference"=> payment.response_code,
      "merchantReference"=> order.number,
      "eventDate"=>"2016-08-03T17:20:23.38Z",
      "value"=>"2000",
    }
  end

  before(:each) do
    # Send a fake capture notification to complete the payment
    notification = AdyenNotification.build(notification_params)
    notification.save!
    Spree::Adyen::NotificationProcessor.new(notification).process!
  end

  context "when the payment is able to be refunded" do
    it "refunds the payment successfully" do
      visit spree.admin_order_payments_path(order)
      expect(page).to have_selector("span.state.completed")
      within_row(1) { click_icon :reply } # Refund uses the reply icon

      VCR.use_cassette "Credit Card Refund", record: :new_episodes do
        select2("Test reason", from: "Reason")
        click_button("Refund")
        expect(page).to have_content("Refund request was received")
        expect(page).to have_selector("span.state.processing")
      end
    end
  end

  context "when the payment is not able to be refunded" do
    before(:each) { payment.update_columns(amount: 0) }

    it "does not allow the admin to refund it" do
      visit spree.admin_order_payments_path(order)
      expect(page).to_not have_selector("a.fa-reply")
    end
  end
end
