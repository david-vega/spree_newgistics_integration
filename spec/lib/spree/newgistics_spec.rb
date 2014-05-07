require 'spec_helper'

describe Newgistics do
  let(:shipment){ Spree::Shipment.last }
  let(:new_shipment){ Spree::Shipment.find 7 }
  let(:shipment_on_hold){ Spree::Shipment.first }

  describe '#search_shipment' do
    it 'returns a list with the shipments' do
      VCR.use_cassette('newgistics_shipment_search') do
        response = Newgistics.search_shipment shipment.external_id
        response.keys.should == ['Shipments']
      end
    end
  end

  describe '#create_shipment' do
    it 'create a shipment in newgistics' do
      VCR.use_cassette('newgistics_shipment_post') do
        response = Newgistics.create_shipment new_shipment
      end
      new_shipment.reload
      new_shipment.external_id.should == '41257253'
      new_shipment.external_status.should == 'ONHOLD'
    end
  end

  describe '#update_shipment_address' do
    it 'updates the shipment address' do
      VCR.use_cassette('newgistics_update_shipment_address') do
        response = Newgistics.update_shipment_address shipment_on_hold
        response['response'].should == { 'success' => 'true' }
      end
    end
  end

  describe '#update_shipment_items' do
    it 'updates the shipment items' do
      VCR.use_cassette('newgistics_update_shipment_items') do
        response = Newgistics.update_shipment_items shipment_on_hold
        response['response'].should == { 'success' => 'true' }
      end
    end
  end

  describe '#update_shipment_status' do
    it 'returns the tracking number and changes the shipment state to shipped' do
      VCR.use_cassette('newgistics_update_shipment') do
        response = Newgistics.update_shipment_status shipment
      end
      shipment.reload
      shipment.tracking.should == '1Z0000000000000'
      shipment.state.should == 'shipped'
    end
  end

  describe '#search_returns' do
    before do
       Time.stub(:now).and_return(Time.parse('2014-04-01 00:00:00 -0600'))
    end

    it 'returns shipmets in return state' do
       VCR.use_cassette('newgistics_search_returns') do
         response = Newgistics.search_returns
         response['Returns']['Return'].size.should == 2
       end
    end
  end
end
