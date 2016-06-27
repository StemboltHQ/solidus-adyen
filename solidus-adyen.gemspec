# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "spree/adyen/version"

Gem::Specification.new do |spec|
  spec.name          = "solidus-adyen"
  spec.version       = Spree::Adyen::VERSION
  spec.authors       = ["Dylan Kendal"]
  spec.email         = ["dylan@stembolt.com"]
  spec.description   = "Adyen HPP payments for Solidus Stores"
  spec.summary       = "Adyen HPP payments for Solidus Stores"
  spec.homepage      = "https://github.com/StemboltHQ/solidus-adyen"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "adyen", "~> 2.2.0"
  spec.add_runtime_dependency "solidus_core", "~> 1.1"
  spec.add_runtime_dependency "bourbon"

  spec.add_development_dependency "sass-rails"
  spec.add_development_dependency "coffee-rails"

  spec.add_development_dependency "pg"

  spec.add_development_dependency "rspec-rails", "~> 3.3"
  spec.add_development_dependency "rspec-activemodel-mocks"
  spec.add_development_dependency "shoulda-matchers"

  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-rcov"

  spec.add_development_dependency "awesome_print"
  spec.add_development_dependency "better_errors"
  spec.add_development_dependency "binding_of_caller"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "pry-stack_explorer"
  spec.add_development_dependency "pry-rails"

  spec.add_development_dependency "capybara"
  spec.add_development_dependency "poltergeist"
  spec.add_development_dependency "launchy"
end
