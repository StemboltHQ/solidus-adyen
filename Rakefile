require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/packagetask'
require 'rubygems/package_task'
require 'rspec/core'
require 'rspec/core/rake_task'
require 'spree/testing_support/extension_rake'

task default: [:spec]

desc 'Generates a dummy app for testing'
task :test_app do
  ENV['LIB_NAME'] = 'solidus-adyen'
  Rake::Task['extension:test_app'].invoke
end
