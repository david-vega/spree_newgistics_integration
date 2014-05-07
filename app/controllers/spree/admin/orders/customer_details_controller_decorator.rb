Spree::Admin::Orders::CustomerDetailsController.class_eval do
  def update
    if @order.update_attributes(order_params)
      if params[:guest_checkout] == "false"
        @order.associate_user!(Spree.user_class.find_by_email(@order.email))
      end
      while @order.next; end

      @order.refresh_shipment_rates
      update_shipments

      flash[:success] = Spree.t('customer_details_updated')
      redirect_to admin_order_customer_path(@order)
    else
      render :action => :edit
    end
  end

  private

  def update_shipments
    @order.shipments.each do |shipment|
      begin
        Newgistics.update_shipment_address shipment if shipment.external_id
      rescue Exception => e
        Rails.logger.warn e
      end
    end
    @order.updater.update
  end
end
