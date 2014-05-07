Spree::Api::ShipmentsController.class_eval do

  def add
    variant = Spree::Variant.find(params[:variant_id])
    quantity = params[:quantity].to_i

    @order.contents.add(variant, quantity, nil, @shipment)

    update_shipments

    respond_with(@shipment, default_template: :show)
  end

  def remove
    variant = Spree::Variant.find(params[:variant_id])
    quantity = params[:quantity].to_i

    @order.contents.remove(variant, quantity, @shipment)

    if @shipment.persisted?
      @shipment.reload
      update_shipments
    end

    respond_with(@shipment, default_template: :show)
  end

  def update_shipments
    begin
      Newgistics.update_shipment_items @shipment if @shipment.external_id
    rescue Exception => e
      Rails.logger.warn e
    end
    @order.updater.update
  end
end
