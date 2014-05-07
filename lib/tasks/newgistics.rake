namespace :newgistics do
  desc 'Synchronize shipments with newgistics'
  task shipmets_sync: :environment do
    ready_shipments = Spree::Shipment.where(state: 'ready').all

    ready_shipments.each do |shipment|
      begin
        if shipment.external_id?
          Newgistics.update_shipment_status shipment
        else
          Newgistics.create_shipment shipment
        end
      rescue Exception => e
        Rails.logger.warn e
      end
    end

    sku_shipments = Spree::Shipment.where(external_status: 'BADSKUHOLD')

    sku_shipments.each do |shipment|
      begin
        Newgistics.update_shipment_items shipment
      rescue Exception => e
        Rails.logger.warn e
      end
    end

    address_shipments = Spree::Shipment.where(external_status: 'BADADDRESS')

    address_shipments.each do |shipment|
      begin
        Newgistics.update_shipment_address shipment
      rescue Exception => e
        Rails.logger.warn e
      end
    end

    hold_shipments = Spree::Shipment.where(external_status: ['CNFHOLD', 'INVHOLD', 'ONHOLD']).all
    hold_shipments.each do |shipment|
      begin
        Newgistics.update_shipment_status shipment
      rescue Exception => e
        Rails.logger.warn e
      end
    end


    return_shipments = Spree::Shipment.where('state = ? AND created_at > ? AND external_status <> ?',
                                             'shipped',
                                             (Time.now - 90.days),
                                             'RETURNED').all

    result = Newgistics.search_returns
    return_shipments.each do |shipment|
      begin
        Newgistics.update_return shipment, result
      rescue Exception => e
        Rails.logger.warn e
      end
    end
  end

  desc 'Send shipment tracking emails'
  task email_sync: :environment do
    shipment_mails = Spree::ShipmentMail.where('state = ? AND delivery_date < ?', 'send', Time.now).all
    shipment_mails.each{ |shipment_mail| shipment_mail.sending }
  end
end
