class AddIndexAdyenNotificationsPspReference < ActiveRecord::Migration
  def change
    add_index :adyen_notifications, [:psp_reference], unique: true
  end
end
