source "https://rubygems.org"

branch = ENV.fetch("SOLIDUS_BRANCH", "master")

if branch == "master" || branch >= "v2.0"
  gem "rails-controller-testing", group: :test
end

if branch == 'master' || branch >= "v2.3"
  gem 'rails', '~> 5.1.0' # HACK: broken bundler dependency resolution
elsif branch >= "v2.0"
  gem 'rails', '~> 5.0.0' # HACK: broken bundler dependency resolution
else
  gem "rails", '~> 4.2.0' # HACK: broken bundler dependency resolution
  gem 'rails_test_params_backport', group: :test
end

group :development, :test do
  gem "solidus", github: 'solidusio/solidus', branch: branch
  gem "solidus_auth_devise"
  gem "deface"

  gem "pg"
  gem "mysql2"
  gem "sqlite3"
end

group :test do
  gem "database_cleaner"
  gem "factory_girl"
  gem "timecop"
  gem "vcr"
  gem "webmock", "~> 1.24"
  gem "selenium-webdriver"
  gem 'chromedriver-helper', require: false
end

gemspec
