rm -rf spec/dummy && bundle install && rake test_app && cd spec/dummy && rake db:migrate && rails s
