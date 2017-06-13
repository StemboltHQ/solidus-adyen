class RecreateAdyenNotificationIndex < SolidusSupport::Migration[4.2]
  def change
    add_index :adyen_notifications, [:psp_reference, :event_code, :success], unique: true, name: "adyen_notification_uniqueness"
  end
end
