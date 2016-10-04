class CreateSpreeAdyenRatepaySources < ActiveRecord::Migration
  def change
    create_table :spree_adyen_ratepay_sources do |t|
      t.string :auth_result
      t.string :psp_reference
      t.string :merchant_reference
      t.integer :payment_method_id, foreign_key: { references: :spree_payment_methods }, index: { name: 'index_ratepay_source_payment_method' }
      t.integer :user_id, foreign_key: { references: :spree_users }, index: true

      t.timestamps null: false
    end

    add_index :spree_adyen_ratepay_sources, :psp_reference, unique: true
    add_index :spree_adyen_ratepay_sources, :merchant_reference
  end
end
