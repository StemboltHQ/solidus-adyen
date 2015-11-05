#!/usr/bin/env ruby
require "bundler/setup"
require "capybara"
require "capybara"
require "capybara/dsl"
require "capybara/poltergeist"
require "pry"

Capybara.default_driver = :poltergeist

class Driver
  include Capybara::DSL

  def amex_purchase
    checkout :norway

    click_link "American Express"

    fill_in "card.cardNumber", with: "370000000000002"
    fill_in "card.cardHolderName", with: "John Doe"
    select "08", from: "card.expiryMonth"
    select "2018", from: "card.expiryYear"
    fill_in "card.cvcCode", with: "7373"

    click_button "continue"
    click_button "pay"
  end

  def sofort_purchase
    checkout :germany

    click_link "Sofort Banking"
    fill_in "Account number", with: "88888888"
    fill_in "PIN", with: "12345"
    click_button "Next"
    find(
      "label",
      text: "23456789 - Girokonto (Max Mustermann)",
      match: :prefer_exact).
    click
    click_button "Next"
    fill_in "TAN", with: "12345"
    click_button "Next"
  end

  def ideal_purchase issuer
    checkout :norway

    click_link "iDEAL"
    select issuer
    click_button "continue"
    click_button "Continue"
  end

  def login
    visit "http://localhost:3000/login"
    fill_in "Email", with: "spree@example.com", match: :first
    fill_in "Password", with: "spree123"

    click_button "Login"
  end

  def checkout address_type
    visit "http://localhost:3000/"
    click_link "Ruby on Rails Tote", match: :first
    click_button "Add To Cart"
    click_button "Checkout"
    fill_address address_type
    click_button "Save and Continue"
    click_button "Save and Continue"
    choose "Adyen"
  end

  def fill_address type
    fill_in "First Name", with: "John"
    fill_in "Last Name", with: "Doe"
    fill_in "Phone", with: "250-111-1111"
    case type
    when :norway
      fill_norway_address
    when :germany
      fill_german_address
    end
  end

  def fill_german_address
    fill_in "Street Address", with: "Gleimstraße 62"
    fill_in "City", with: "Berlin"
    select "Germany"
    select "Berlin"
    fill_in "Zip", with: "13355"
  end

  def fill_norway_address
    fill_in "Street Address", with: "Noordwal 540"
    fill_in "City", with: "Den Haag"
    select "Netherlands"
    select "Zuid-Holland"
    fill_in "Zip", with: "2513dz"
  end
end

driver = Driver.new

driver.login
driver.sofort_purchase
driver.amex_purchase
driver.ideal_purchase "Test Issuer"
# driver.ideal_purchase "Test Issuer Refused"
# driver.ideal_purchase "Test Issuer Pending"
# driver.ideal_purchase "Test Issuer Cancelled"
