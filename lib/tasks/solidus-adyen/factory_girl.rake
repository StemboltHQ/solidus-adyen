namespace :"solidus-adyen" do
  namespace :factory_girl do
    desc "Verify that all FactoryGirl factories are valid"
    task lint: :environment do
      if Rails.env.test?
        begin
          DatabaseCleaner.start
          FactoryGirl.lint
        ensure
          DatabaseCleaner.clean
        end
      else
        system("bundle exec rake soldius-adyen:factory_girl:lint RAILS_ENV='test'")
      end
    end
  end
end
