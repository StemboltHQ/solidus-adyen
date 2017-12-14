if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-rcov"
  SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
  SimpleCov.start
end

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require "spree"

begin
  require File.expand_path("../dummy/config/environment.rb",  __FILE__)
rescue LoadError
  puts "Could not load dummy application. Please ensure you have run `bundle exec rake test_app`"
end

require "rspec/rails"
require "rspec/active_model/mocks"
require "vcr"
require "ffaker"
require "shoulda/matchers"
require "pry"
require "database_cleaner"
require "capybara/poltergeist"

require "spree/testing_support/factories"
require 'spree/testing_support/capybara_ext'
require "spree/testing_support/controller_requests"
require "spree/testing_support/url_helpers"
require "spree/testing_support/authorization_helpers"

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f }

FactoryGirl.definition_file_paths = %w{./spec/factories}
FactoryGirl.find_definitions

Capybara.javascript_driver = :poltergeist
Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome)
end

RSpec.configure do |config|
  RSpec::Matchers.define_negated_matcher :keep, :change

  config.color = true
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.use_transactional_fixtures = false
  config.example_status_persistence_file_path = "./spec/examples.txt"

  config.include ControllerHelpers, type: :controller
  config.include Devise::TestHelpers, type: :controller
  config.include Spree::TestingSupport::ControllerRequests, type: :controller
  config.include FactoryGirl::Syntax::Methods
  config.include Spree::TestingSupport::ControllerRequests, type: :controller
  config.include Spree::TestingSupport::UrlHelpers

  config.when_first_matching_example_defined(type: :feature) do
    config.before(:suite) do
      Rails.application.precompiled_assets
    end
  end

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each, type: :feature, js: true) do |ex|
    Capybara.current_driver = ex.metadata[:driver] || :poltergeist
  end

  config.around(:each) do |example|
    ActiveJob::Base.queue_adapter = :test

    DatabaseCleaner.strategy =
      example.metadata[:truncation] ? :truncation : :transaction
    DatabaseCleaner.start

    example.run

    DatabaseCleaner.clean
  end
end

ENV["ADYEN_API_PASSWORD"] ||= "fake_api_password"
ENV["ADYEN_API_USERNAME"] ||= "fake_api_username"
ENV["ADYEN_MERCHANT_ACCOUNT"] ||= "fake_api_merchant_account"
ENV["ADYEN_CSE_LIBRARY_LOCATION"] ||= "test-adyen-encrypt.js"

VCR.configure do |c|
  # c.allow_http_connections_when_no_cassette = true
  c.ignore_localhost = true
  c.cassette_library_dir = "spec/cassettes"
  c.hook_into :webmock
  c.filter_sensitive_data('<ADYEN_API_PASSWORD>') { Rack::Utils.escape(ENV["ADYEN_API_PASSWORD"]) }
  c.filter_sensitive_data('<ADYEN_API_USERNAME>') { Rack::Utils.escape(ENV["ADYEN_API_USERNAME"]) }
  c.filter_sensitive_data('<ADYEN_MERCHANT_ACCOUNT>') { ENV["ADYEN_MERCHANT_ACCOUNT"] }
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
