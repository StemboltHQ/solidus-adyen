if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-rcov"
  SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
  SimpleCov.start
end

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require 'spree'

begin
  require File.expand_path("../dummy/config/environment.rb",  __FILE__)
rescue LoadError
  puts "Could not load dummy application. Please ensure you have run `bundle exec rake test_app`"
end

require 'rspec/rails'
require 'rspec/active_model/mocks'
require 'vcr'
require 'ffaker'
require 'shoulda/matchers'
require 'pry'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f }

require 'spree/testing_support/factories'
require 'spree/testing_support/controller_requests'
require 'spree/testing_support/url_helpers'
require "support/shared_contexts/mock_adyen_api"

FactoryGirl.definition_file_paths = %w{./spec/factories}
FactoryGirl.find_definitions

module Spree
  module Adyen
    module TestHelper
      def test_credentials
        @tc ||= YAML::load_file(File.new("#{Engine.config.root}/config/credentials.yml"))
      end
    end
  end
end

RSpec.configure do |config|
  config.color = true
  config.infer_spec_type_from_file_location!
  config.mock_with :rspec
  config.use_transactional_fixtures = true
  config.example_status_persistence_file_path = './spec/examples.txt'

  config.include Spree::TestingSupport::ControllerRequests, type: :controller
  config.include FactoryGirl::Syntax::Methods
  config.include Spree::TestingSupport::UrlHelpers

  config.filter_run_excluding :external => true

  config.include Spree::Adyen::TestHelper
end

VCR.configure do |c|
  # c.allow_http_connections_when_no_cassette = true
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
