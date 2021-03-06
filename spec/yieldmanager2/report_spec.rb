require 'spec_helper'

REPORT_NEED_ENV_ARGS_MSG = <<EOM
Please set these environment variables to match your Yieldmanager account:
* YIELDMANAGER_USER
* YIELDMANAGER_PASS
* YIELDMANAGER_CONTACT_ID (get this from the contact_id attribute in any UI-created reportware report)
* YIELDMANAGER_IP_ADDRESS (your external IP address)
* YIELDMANAGER_ACCT_ID (get this from the entity or filter_entity_id field attribute in any UI-created reportware report)
EOM
  
describe "A Yieldmanager report request" do

  before(:each) do
    @ym = Yieldmanager2::Client.new(login_args)
    @sample_report = File.join(File.dirname(__FILE__), '..', 'reports', 'sample_report.xml')
  end
  
  it "returns report object", :vcr => true do
    @ym.session do |token|
      rpt = @ym.pull_report(token, request_xml)
      rpt.should be_instance_of(Yieldmanager2::Report)
    end
  end
  
  it "makes request and returns report token", :vcr => true do
    @ym.session do |token|
      rpt = Yieldmanager2::Report.new
      rpt.send(:request_report_token, token, @ym.report, request_xml).should_not be_nil
    end
  end
  
  it "uses report token to pull report url", :vcr => true do
    @ym.session do |token|
      rpt = Yieldmanager2::Report.new
      report_token = rpt.send(:request_report_token, token, @ym.report, request_xml)
      report_url = rpt.send(:retrieve_report_url, token, @ym.report, report_token)
      report_url.should_not be_nil
    end
  end
  
  it "uses report url to pull report", :vcr => true do
    @ym.session do |token|
      rpt = Yieldmanager2::Report.new
      report_token = rpt.send(:request_report_token, token, @ym.report, request_xml)
      report_url = rpt.send(:retrieve_report_url, token, @ym.report, report_token)

      rpt.send(:retrieve_data, report_url)
      rpt.headers[0].should == "advertiser_name"
    end
  end
  
  it "offers data as array of arrays" do
    report = Yieldmanager2::Report.new
    report.send(:retrieve_data, @sample_report)
    report.data[0][0].should == "one"
  end
  
  it "offers data by name" do
    report = Yieldmanager2::Report.new
    report.send(:retrieve_data, @sample_report)
    report.data[0].by_name('first').should == "one"
    report.data[1].by_name(:second).should == "2"
  end
  
  it "offers data as array of hashes" do
    report = Yieldmanager2::Report.new
    report.send(:retrieve_data, @sample_report)
    hashes = report.to_hashes
    hashes.size.should == 2
    hashes[0]['first'].should == "one"
    hashes[1]['second'].should == "2"
  end

  it "by_name returns 'column not found' error when missing" do
    report = Yieldmanager2::Report.new
    report.send(:retrieve_data, @sample_report)
    begin
      report.data.first.by_name('does_not_exist')
      fail "Should have thrown ArgumentError"
    rescue => e
      e.class.name.should == "ArgumentError"
      e.message.should == "Column not found: 'does_not_exist'"
    end
  end

  it "supports data report faking" do
    report = Yieldmanager2::Report.new
    report.headers = ["first","second"]
    report.add_row([1,2])
    report.data.first.by_name("first").should == 1
    report.data.first.by_name("second").should == 2
  end

  it "supports header name editing after data pull" do
    report = Yieldmanager2::Report.new
    report.send(:retrieve_data, @sample_report)
    report.data.first.by_name('first').should == "one"
    report.headers[0] = 'new_first'
    report.data.first.by_name('new_first').should == "one"
  end
  
  def login_args
    unless ENV["YIELDMANAGER_USER"] &&
      ENV["YIELDMANAGER_PASS"]
      raise(ArgumentError, REPORT_NEED_ENV_ARGS_MSG)
    end
    @login_args ||= {
      :user => ENV["YIELDMANAGER_USER"],
      :pass => ENV["YIELDMANAGER_PASS"],
      :env => "test"
    }
  end

  def request_xml
    unless ENV["YIELDMANAGER_CONTACT_ID"] &&
      ENV["YIELDMANAGER_IP_ADDRESS"] &&
      ENV["YIELDMANAGER_ACCT_ID"]
      raise(ArgumentError, REPORT_NEED_ENV_ARGS_MSG)
    end
    <<EOR
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
  end
end
