class RemoveCharLimitFromPspReference < SolidusSupport::Migration[4.2]
  def up
    change_column :adyen_notifications, :psp_reference, :string, limit: nil
  end

  def down
    change_column :adyen_notifications, :psp_reference, :string, limit: 50
  end
end
