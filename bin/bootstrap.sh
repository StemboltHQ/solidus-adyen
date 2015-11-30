#!/bin/bash
bundle exec rake test_app DB=postgres
cd spec/dummy
bundle exec rake db:schema:load
bundle exec rake db:seed AUTO_ACCEPT=1
bundle exec rake spree_sample:load

sed -i.bak "s/USD/EUR/" config/initializers/spree.rb
