source "https://rubygems.org"

group :development, :test do
  gem "solidus"
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
end

gemspec

gem 'adyen', github: 'wvanbergen/adyen', branch: 'hpp', ref: '9f943f8'
