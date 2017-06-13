class AddIndexAdyenNotificationsPspReference < SolidusSupport::Migration[4.2]
  def change
    add_index :adyen_notifications, [:psp_reference], unique: true
  end
end
