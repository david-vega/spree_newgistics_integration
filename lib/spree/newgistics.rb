class Newgistics
  class << self
    CANCEL_STATES = %w( CNFHOLD CANCELED BADSKUHOLD BADADDRESS INVHOLD ONHOLD )

    def search_shipment id
      HTTParty.get("#{NEWGISTICS_CONFIG['url']}/shipments.aspx",
                   query: {key: NEWGISTICS_CONFIG['api_key'],
                           shipmentid: id})
    end

    def search_returns
      HTTParty.get("#{NEWGISTICS_CONFIG['url']}/returns.aspx",
                   query: {key: NEWGISTICS_CONFIG['api_key'],
                           starttimestamp: Time.now - 90.days,
                           endtimestamp: Time.now})
    end

    def update_shipment_status shipment
      result = search_shipment shipment.external_id
      shipment_response = result.parsed_response['Shipments']

      if shipment_response.has_key?('Errors')
        shipment_response
      else
        update_status(shipment_response['Shipment'], shipment)
      end
    end

    def update_shipment_address shipment
      document = update_shipment_address_document shipment
      result = send_to_newgistics document, '/update_shipment_address.aspx'
      update_shipment_status shipment
      result
    end

    def update_shipment_items shipment
      document = update_shipment_items_document shipment
      result = send_to_newgistics document, '/update_shipment_contents.aspx'
      update_shipment_status shipment
      result
    end

    def create_shipment shipment
      document = create_shipment_document shipment
      result = send_to_newgistics document, '/post_shipments.aspx'

      shipment.update_attributes!(external_id: result.parsed_response['response']['shipments']['shipment']['id'])
      update_shipment_status shipment
      result
    end

    def update_return shipment, result
      shipment_result = result.parsed_response['Returns']['Return']
      generate_return shipment, shipment_result
    end

    private

    def update_status response, shipment
      unless response['ShipmentStatus'] == shipment.external_status
        shipment.update_attributes!(external_status: response['ShipmentStatus'])
      end

      shipment.order.updater.update

      status_shipped(shipment, response['Tracking']) if (response['ShipmentStatus'] == 'SHIPPED') && (shipment.state != 'shipped')

      status_canceled(shipment) if (CANCEL_STATES.include? response['ShipmentStatus']) && (shipment.state != 'canceled')

      update_return(shipment, search_returns) if (response['ShipmentStatus'] == 'RETURNED') && (shipment.state != 'shipped')

    end

    def status_shipped shipment, tracking
      shipment.update_attributes!(tracking: tracking)
      shipment.ship!
    end

    def status_canceled shipment
      shipment.cancel!
      shipment.order.update_attributes!(shipment_state: 'canceled')
    end

    def generate_return shipment, shipment_result
      order = shipment.order
      shipment_result = find_shipment_order(shipment_result, order.number) if (shipment_result.class == Array)
      if shipment_result
        shipment.update_attributes!(external_status: 'RETURNED')
        return_authorization = order.return_authorizations.create!(reason: "#{shipment_result['Reason']}
                                                                           ------------------
                                                                           #{shipment_result['Condition']}")
      end
    end

    def find_shipment_order shipment_result, order_number
      shipment_result.find {|shipment| shipment['orderID'] == order_number }
    end

    def send_to_newgistics document, url
      result = HTTParty.post("#{NEWGISTICS_CONFIG['url']}#{url}",
                             body: document.to_xml)
    end

    def shipment_date shipment
      date = shipment.order.completed_at || Time.now
      date.strftime('%m/%d/%Y')
    end

    def create_shipment_document shipment
      address = shipment.order.shipping_address
      document = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.Orders(apiKey: NEWGISTICS_CONFIG['api_key']) {
          xml.Order(orderID: shipment.order.number){
            xml.CustomerInfo{
              xml.Company address.company
              xml.FirstName address.firstname
              xml.LastName address.lastname
              xml.Address1 address.address1
              xml.Address2 address.address2
              xml.City address.city
              xml.State address.state.name || address.state_name
              xml.Country address.country.name
              xml.Zip address.zipcode
              xml.Email shipment.order.email
              xml.Phone address.phone
            }
            xml.OrderDate shipment_date(shipment)
            xml.ShipMethod shipment.shipping_method.admin_name
            xml.RequiresSignature shipment.order.confirmation_delivered ? 'YES' : 'NO'
            xml.AddGiftWrap shipment.order.gift_message ? 'YES' : 'NO'
            xml.GiftMessage shipment.order.gift_message
            xml.Items{
              shipment.order.line_items.each do |item|
                xml.Item{
                  xml.SKU item.variant.sku
                  xml.Qty item.quantity
                }
              end
            }
          }
        }
      end
    end

    def update_shipment_address_document shipment
      address = shipment.order.shipping_address
      document = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.updateShipment(apiKey: NEWGISTICS_CONFIG['api_key'], id: shipment.external_id) {
          xml.Company address.company
          xml.FirstName address.firstname
          xml.LastName address.lastname
          xml.Address1 address.address1
          xml.Address2 address.address2
          xml.City address.city
          xml.State address.state.name || address.state_name
          xml.Country address.country.name
          xml.Zip address.zipcode
          xml.Email shipment.order.email
          xml.Phone address.phone
        }
      end
    end

    def update_shipment_items_document shipment
      old_shipment = search_shipment shipment.external_id
      old_items = old_shipment['Shipments']['Shipment']['Items']
      document = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.Shipment(apiKey: NEWGISTICS_CONFIG['api_key'], id: shipment.external_id) {
          xml.AddItems{
            shipment.order.line_items.each do |item|
              xml.Item{
                xml.SKU item.variant.sku
                xml.Qty item.quantity
              }
            end
          }
          if old_items
            xml.RemoveItems{
              if  old_items['Item'].class == Array
                old_items.each do |item|
                  xml.Item{
                    xml.SKU item['Item']['SKU']
                    xml.Qty item['Item']['Qty']
                  }
                end
              else
                xml.Item{
                  xml.SKU old_items['Item']['SKU']
                  xml.Qty old_items['Item']['Qty']
                }
              end
            }
          end
        }
      end
    end
  end
end
