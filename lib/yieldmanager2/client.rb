module Yieldmanager2
  class Client

    Services = %w{
      adjustment
      campaign
      contact
      creative
      dictionary
      entity
      insertion_order
      line_item
      linking
      notification
      pixel
      quota
      report
      search
      section
      segment_definition
      site
      target_profile
      xsd_gen
    }

    attr_accessor :user, :pass, :env, :api_version

    def initialize login_args = {}
      @user = login_args['user'] || login_args[:user] || ENV['YIELDMANAGER_USER']
      @pass = login_args['pass'] || login_args[:pass] || ENV['YIELDMANAGER_PASS']
      @env  = login_args['env']  || login_args[:env]  || ENV['YIELDMANAGER_ENV'] || "prod"
      @api_version = login_args['api_version'] || login_args[:api_version] || ENV['YIELDMANAGER_API_VERSION']
      raise "User, pass and api_version are required. See docs for options." unless (@user && @pass && @env)
      @api_base = "https://api.yieldmanager.com/api-#{@api_version}"
      @api_test_base = "https://api-test.yieldmanager.com/api-#{@api_version}"
      @contact = load_service("contact")
      wrap_services
    end

    def available_services
      Services
    end

    def start_session
      token = @contact.login({
        :user => @user,
        :pass => @pass,
        :env => @env,
        :login_options => {:errors_level => 'throw_errors', :multiple_sessions => '1'}
      })
      token
    end

    def end_session token
      @contact.logout(token)
    end

    def session
      token = start_session
      begin
        yield token
      ensure
        end_session token
      end
    end
        
    # Allows looping over datasets too large to pull back in one call
    #   
    # Block must return total rows in dataset to know when to stop!
    def paginate block_size
      page = 1 
      total = block_size + 1 

      begin
        total = yield page # Need total back from block to know when to stop!
        page += 1
      end until (block_size * (page-1)) > total
    end 

    def pull_report token, xml
      report_svc = report
      rpt = Yieldmanager2::Report.new()
      rpt.pull(token, report_svc, xml)
      rpt
    end

private

    def wrap_services
      Services.each do |s|
        self.class.send(:attr_writer, s.to_sym)
        # create wrapper method to load it when requested
        self.class.send(:define_method, s) {
          unless self.instance_variable_get("@#{s}")
            self.instance_variable_set("@#{s}",load_service(s))
          end
          self.instance_variable_get("@#{s}")
        }
      end
    end

    def load_service svc
      base_url = (@env == "test") ? @api_test_base : @api_base
      wsdl_url = "#{base_url}/#{svc}.php?wsdl"

      svc = Savon::Client.new do
        wsdl.document = wsdl_url
      end
      svc.extend(Yieldmanager2::Service)
    end
  end
end
