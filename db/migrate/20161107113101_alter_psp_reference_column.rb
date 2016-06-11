class AlterPspReferenceColumn < ActiveRecord::Migration
  def up
    change_column :adyen_notifications, :psp_reference, :string, limit: 255
  end

  def down
    change_column :adyen_notifications, :psp_reference, :string, limit: 50
  end
end
