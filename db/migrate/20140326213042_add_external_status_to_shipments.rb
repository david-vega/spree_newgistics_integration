class AddExternalStatusToShipments < ActiveRecord::Migration
  def change
    add_column :spree_shipments, :external_status, :string
  end
end
