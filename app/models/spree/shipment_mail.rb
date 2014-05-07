module Spree
  class ShipmentMail < ActiveRecord::Base
    belongs_to :shipment

    scope :pending, -> { with_state('pending') }

    state_machine :state, initial: :pending do
      before_transition pending: :send, do: :send_tracking_email

      event :sending do
        transition pending: :send
      end

      event :pend do
        transition send: :pending
      end
    end

    validates :shipment_id, presence: true

    before_save :set_send_time

    private

    def send_tracking_email
      ShipmentMailer.shipped_email(self.shipment.id).deliver
    end

    def set_send_time
      self.delivery_date = Time.now + 24.hours
    end
  end
end
