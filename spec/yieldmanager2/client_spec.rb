require 'spec_helper'

INACTIVE= false
CLIENT_NEED_ENV_ARGS_MSG = <<EOM
Please set these environment variables to match your Yieldmanager account:
* YIELDMANAGER_USER
* YIELDMANAGER_PASS
* YIELDMANAGER_API_VERSION
* YIELDMANAGER_CONTACT_ID (get this from the contact_id attribute in any UI-created reportware report)
* YIELDMANAGER_IP_ADDRESS (your external IP address)
* YIELDMANAGER_ACCT_ID (get this from the entity or filter_entity_id field attribute in any UI-created reportware report)
EOM

describe "A Yieldmanager client" do
  let(:line_item_id) { ENV['YIELDMANAGER_LINE_ITEM'] }
  let(:adv_id) { ENV['YIELDMANAGER_ADV'] }

  before(:each) do
    @ym = Yieldmanager2::Client.new(:env => "test")
  end

  it "logs connections on request", :vcr => true do
    strio = StringIO.new
    l = Logger.new(strio)
    Savon.configure{ |config| config.log = true; config.logger = l }
    ym2 = Yieldmanager2::Client.new
    ym2.session do |token|
      currencies = ym2.dictionary.getCurrencies(token)
    end
    Savon.configure{ |config| config.log = false }
    strio.string.should include("getCurrencies")
  end
  
  it "defaults to environment variables if not supplied" do
    ym = Yieldmanager2::Client.new
    ym.user.should == ENV['YIELDMANAGER_USER']
    ym.pass.should == ENV['YIELDMANAGER_PASS']
    ym.api_version.should == ENV['YIELDMANAGER_API_VERSION']
    ym.env.should == (ENV['YIELDMANAGER_ENV'] || "prod")
  end
  
  it "accepts 'user', 'pass' as string args" do
    ym = Yieldmanager2::Client.new(
      'user' => 'STRING_USER',
      'pass' => 'STRING_PASS',
      'api_version' => 'STRING_API_VERSION',
      'env'  => 'STRING_ENV'
    )
    ym.user.should == 'STRING_USER'
    ym.pass.should == 'STRING_PASS'
    ym.api_version.should == 'STRING_API_VERSION'
    ym.env.should  == 'STRING_ENV'
  end

  it "accepts :user, :pass as symbol args" do
    ym = Yieldmanager2::Client.new(
      :user => 'SYM_USER',
      :pass => 'SYM_PASS',
      :api_version => 'SYM_API_VERSION',
      :env  => 'SYM_ENV'
    )
    ym.user.should == 'SYM_USER'
    ym.pass.should == 'SYM_PASS'
    ym.api_version.should == 'SYM_API_VERSION'
    ym.env.should  == 'SYM_ENV'
  end
  
  it "defaults to prod, accepts override to test" do
    ym_prod = Yieldmanager2::Client.new()
    ym_prod.env.should == "prod"
    ym_prod.contact.inspect.should match("api.yieldmanager.com")
    ym_test = Yieldmanager2::Client.new(login_args.merge(:env => "test"))
    ym_test.env.should == "test"
    ym_test.contact.inspect.should match("api-test.yieldmanager.com")
    ym_test2 = Yieldmanager2::Client.new(login_args.merge('env' => "test"))
    ym_test2.env.should == "test"
    ym_test2.contact.inspect.should match("api-test.yieldmanager.com")
  end

  it "fails if no arg or env var found for config" do
    hold_user = ENV['YIELDMANAGER_USER']
    ENV['YIELDMANAGER_USER'] = nil
    begin
      bad_ym = Yieldmanager2::Client.new
      fail "Should complain about missing user"
    rescue Exception => e
      e.message.should eq("User, pass and api_version are required. See docs for options.")
    ensure
      ENV['YIELDMANAGER_USER'] = hold_user
    end
  end
  
  it "displays available services" do
    @ym.available_services.should include("contact")
    ym_test = Yieldmanager2::Client.new(login_args.merge(:env => "test"))
    ym_test.available_services.should include("contact")
  end
  
  it "exposes helper methods for available services" do
    @ym.contact.should be_instance_of(Savon::Client)
  end
  
  it "generates contact service supporting login/logout of session", :vcr => true do
    token = @ym.contact.login(@ym.user,@ym.pass,{'errors_level' => 'throw_errors','multiple_sessions' => '1'})
    begin
      token.should_not be_nil
    ensure
      @ym.contact.logout(token)
    end
  end
  
  it "exposes start/end session", :vcr => true do
    token = @ym.start_session
    currencies = @ym.dictionary.getCurrencies(token)
    @ym.end_session token
    expect{ @ym.dictionary.getCurrencies(token) }.to raise_error(/Session expired or not created./)
  end
  
  it "exposes session block", :vcr => true do
    my_token = nil
    @ym.session do |token|
      my_token = token
      currencies = @ym.dictionary.getCurrencies(token)
    end
    expect{ @ym.dictionary.getCurrencies(my_token) }.to raise_error(/Session expired or not created./)
  end
  
  it "closes a session even after an exception", :vcr => true do
    my_token = nil
    lambda do
      @ym.session do |token|
        my_token = token
        raise Exception, "Ouch!"
      end
    end.should raise_error(Exception)
    expect{ @ym.dictionary.getCurrencies(my_token) }.to raise_error(/Session expired or not created./)
  end

  it "return values can be treated as hashes", :vcr => true do
    @ym.session do |t|
      line = @ym.line_item.get(t,line_item_id)
      line[:id].should eq(line_item_id.to_s)
      line[:description].size.should > 0
      adv = @ym.entity.get(t,adv_id)
      adv[:id].should eq(adv_id.to_s)
      adv[:name].size.should > 0
    end
  end

  it "return value collections can be treated as hashes", :vcr => true do
    @ym.session do |t|
      (lines, tot) = @ym.line_item.getByBuyer(t,adv_id)
      lines.class.should eq(Array)
      lines.each do |l|
        l[:id].should_not be_nil
        l[:description].size.should > 0
      end
    end
  end
  
  it "paginates", :vcr => true do
    BLOCK_SIZE = 50
    id = -1
    @ym.session do |token|
      line_item_service = @ym.line_item
      [
        {:calls_expected => 2, :dataset_size => 75},
        {:calls_expected => 1, :dataset_size => 25},
        {:calls_expected => 1, :dataset_size => 0}
      ].each do |args|
        line_item_service.
          should_receive(:getByBuyer).
          exactly(args[:calls_expected]).times.
          and_return([[],args[:dataset_size]])
        @ym.paginate(BLOCK_SIZE) do |block|
          (lines,tot) = line_item_service.
            getByBuyer(token,id,BLOCK_SIZE,block)
          # must return total rows in dataset
          # so paginate knows when to stop!
          tot
        end
      end
    end
  end
  
  it "ignores bogus 'cannot be null' errors" do
    desc = "bogus line - delete"
    l = {
      :description => desc,
      :status => INACTIVE,
      :insertion_order_id => -1,
      :start_time => "#{Date.today-1}T05:00:00", #offset by timezone
      :end_time => "#{Date.today}T05:00:00", # offset by timezone
      :pricing_type => "CPM",
      :amount => 0.00,
      :budget => 0.00,
      :imp_budget => 0,
      :priority => "Normal"
    }
    lambda { @ym.session { |t| @ym.line_item.add(t,l) } }.
      should_not raise_error(/enum_ym_numbers_difference: cannot accept ''/)
  end
  
  describe "A Yieldmanager report" do

    before(:each) do
      @ym = Yieldmanager2::Client.new(login_args)
    end
    
    it "returns data" do
      request_xml.should include("advertiser_id")
    end
  end
  
  def login_args
    unless ENV["YIELDMANAGER_USER"] &&
      ENV["YIELDMANAGER_PASS"]
      raise(ArgumentError, CLIENT_NEED_ENV_ARGS_MSG)
    end
    @login_args ||= {
      :user => ENV["YIELDMANAGER_USER"],
      :pass => ENV["YIELDMANAGER_PASS"]
    }
  end

  def request_xml
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
