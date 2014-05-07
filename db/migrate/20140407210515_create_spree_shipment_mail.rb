class CreateSpreeShipmentMail < ActiveRecord::Migration
  def change
    create_table :spree_shipment_mails do |t|
      t.string     :state,            default: 'pending'
      t.datetime   :delivery_date
      t.integer    :shipment_id

      t.timestamps
    end
  end
end
