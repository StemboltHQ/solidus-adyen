class CreateSpreeAdyenRedirectResponses < SolidusSupport::Migration[4.2]
  def change
    create_table :spree_adyen_redirect_responses do |t|
      t.text :md
      t.text :pa_request
      t.string :issuer_url
      t.string :psp_reference
      t.integer :payment_id, index: true, null: false

      t.timestamps
    end
    add_foreign_key :spree_adyen_redirect_responses, :spree_payments, column: :payment_id
  end
end
