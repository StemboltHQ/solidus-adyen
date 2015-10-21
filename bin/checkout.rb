#!/usr/bin/env ruby
require "bundler/setup"
require "capybara"
require 'capybara'
require 'capybara/dsl'
require 'capybara/poltergeist'
require "pry"

Capybara.default_driver = :poltergeist

class Driver
  include Capybara::DSL

  def amex_purchase
    checkout

    click_link "American Express"

    fill_in "card.cardNumber", with: "370000000000002"
    fill_in "card.cardHolderName", with: "John Doe"
    select "08", from: "card.expiryMonth"
    select "2018", from: "card.expiryYear"
    fill_in "card.cvcCode", with: "7373"

    click_button "continue"
    click_button "pay"
  end

  def ideal_purchase issuer
    checkout

    click_link "iDEAL"
    select issuer
    click_button "continue"
    click_button "Continue"
    save_and_open_screenshot
  end

  def login
    visit "http://localhost:3000/login"
    fill_in "Email", with: "spree@example.com", match: :first
    fill_in "Password", with: "spree123"

    click_button "Login"
  end

  def checkout
    visit "http://localhost:3000/"
    click_link "Ruby on Rails Tote"
    click_button "Add To Cart"
    click_button "Checkout"
    click_button "Save and Continue"
    click_button "Save and Continue"
    choose "Adyen"
  end
end

driver = Driver.new

driver.login
driver.amex_purchase
driver.ideal_purchase "Test Issuer"
driver.ideal_purchase "Test Issuer Refused"
driver.ideal_purchase "Test Issuer Pending"
driver.ideal_purchase "Test Issuer Cancelled"
