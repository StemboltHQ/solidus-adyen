class AddDaysToShipToConfig < SolidusSupport::Migration[4.2]
  def change
    add_column :spree_adyen_hpp_sources, :days_to_ship, :integer
  end
end
