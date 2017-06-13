class AllowMerchantReferenceToBeNullForAdyenNotification < SolidusSupport::Migration[4.2]
  def change
    change_column :adyen_notifications, :merchant_reference, :string, null: true
  end
end
