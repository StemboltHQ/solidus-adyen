source "https://rubygems.org"

gem 'rails', '~> 5.0.1'

group :development, :test do
  gem 'solidus', '~> 2.2.1'
  gem "solidus_auth_devise"

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
end

gemspec
