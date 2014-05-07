Spree::Shipment.class_eval do

  def update!(order)
    old_state = state
    new_state = determine_state(order)
    update_columns(
        state: new_state,
        updated_at: Time.now,
    )

    create_external_shipment if (new_state == 'ready') && (external_id.nil?)

    after_ship if new_state == 'shipped' and old_state != 'shipped'
  end

  def after_ship
    inventory_units.each &:ship!
    #create_shipment_mail! #TODO activate to send emails with rake newgistics:email_sync
    touch :shipped_at
    update_order_shipment_state
  end

  def create_external_shipment
    begin
      Newgistics.create_shipment self
    rescue Exception => e
      Rails.logger.warn e
    end
  end

end
