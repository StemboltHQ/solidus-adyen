class AddAdyenTokenToSpreeCreditCards < SolidusSupport::Migration[5.0]
  def change
    add_column :spree_credit_cards, :adyen_token, :text
  end
end
