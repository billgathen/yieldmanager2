require 'spec_helper'

describe "VCR", :vcr => true do
  let(:ym) { Yieldmanager2::Client.new(:env => 'test') }
  let(:test_adv) { ENV['YIELDMANAGER_ADV'] }

  it "can mock client hits" do
    ym.session do |t|
      (lines, tot) = ym.line_item.getByBuyer(t,test_adv)
      lines.size.should > 0
      tot.to_i.should > 0
    end
  end

  it "can mock report hits", :vcr => true do
    request_xml = <<EOR
<?xml version="1.0"?>
<RWRequest clientName="ui.ent.prod">
  <REQUEST domain="network" service="ComplexReport" nocache="n" contact_id="#{ENV['YIELDMANAGER_CONTACT_ID']}" remote_ip_address="#{ENV['YIELDMANAGER_IP_ADDRESS']}" entity="#{ENV['YIELDMANAGER_ACCT_ID']}" filter_entity_id="#{ENV['YIELDMANAGER_ACCT_ID']}" timezone="EST">
    <ROWS>
      <ROW type="group" priority="1" ref="entity_id" includeascolumn="n"/>
      <ROW type="group" priority="2" ref="advertiser_id" includeascolumn="n"/>
      <ROW type="total"/>
    </ROWS>
    <COLUMNS>
      <COLUMN ref="advertiser_name"/>
      <COLUMN ref="seller_imps"/>
    </COLUMNS>
    <FILTERS>
      <FILTER ref="time" macro="yesterday"/>
    </FILTERS>
  </REQUEST>
</RWRequest>
EOR
    ym.session do |token|
      rpt = ym.pull_report(token, request_xml)
      rpt.should be_instance_of(Yieldmanager2::Report)
    end
  end
end
