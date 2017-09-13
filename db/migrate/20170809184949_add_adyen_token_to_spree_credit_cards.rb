class AddAdyenTokenToSpreeCreditCards < SolidusSupport::Migration[4.2]
  def change
    add_column :spree_credit_cards, :adyen_token, :text
  end
end
