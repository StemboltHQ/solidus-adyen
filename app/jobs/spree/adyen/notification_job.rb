module Spree::Adyen
  class NotificationJob < ApplicationJob
    queue_as :default

    def perform(notification)
      Spree::Adyen::NotificationProcessor.new(notification).process!
    end
  end
end
