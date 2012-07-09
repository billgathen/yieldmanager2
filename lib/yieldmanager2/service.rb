module Yieldmanager2
  module Service
    def get_name
      /.*\/(\w+).php.*/.match(wsdl.document)[1]
    end

    def available_methods
      wsdl.operations.map{ |k,v| v[:input] }.sort
    end

    def method_missing(meth, *args, &block)
      if available_methods.include?(meth.to_s)
        process_request(meth, args)
      else
        # make sure typos, etc. fall through
        raise NoMethodError.new("undefined method '#{meth}' for #{get_name}",meth)
      end
    end

    def process_request meth, args
      final_args = {}
      if args && args.first.kind_of?(Hash)
        final_args = args.first
      else
        final_args = build_arg_hash meth, args
      end
      rsp = request meth do
        soap.body = final_args
      end
      response_type = response_type_for(meth)
      method_response = rsp[response_type]
      build_return_values(meth,method_response)
    end

    def build_arg_hash meth, args
      method_args(meth).zip(args).inject({}) { |h,k_v| h[k_v.first] = k_v.last; h }
    end

    def build_return_values meth, rsp
      val_names = method_return_values(meth)
      vals = val_names.map do |name|
        field = rsp[name.to_sym]
        if field.kind_of?(Hash) && field[:"@xsi:type"].include?("array_of")
          field.values.first # extract array from hash element containing array
        else
          field
        end
      end
      vals.size == 1 ? vals.first : vals
    end

    def response_type_for meth
      snake_meth = meth.to_s.gsub(/(.)([A-Z])/,'\1_\2').downcase
      snake_meth.sub!(/_xm_l/, '_xml') # doesn't like XML
      "#{snake_meth}_response".to_sym
    end

    def method_args meth
      inputs = method_input(meth)[:part]
      if inputs.kind_of?(Array)
        inputs.map{ |p| p[:@name] }
      else
        [inputs[:@name]]
      end
    end

    def method_return_values meth
      list = method_output(meth)[:part]
      if list.kind_of?(Array)
        list.map{ |p| p[:@name] }
      elsif list.nil? # no return args
        []
      else
        [list[:@name]]
      end
    end

    def method_input meth
      inp = method_messages(meth)
      inp.select{ |msg| msg[:@name] == "#{meth}Input" }.first
    end

    def method_output meth
      out = method_messages(meth)
      out.select{ |msg| msg[:@name] == "#{meth}Output" }.first
    end

    def method_messages meth
      all = all_messages
      all.select{ |msg| msg[:@name].start_with?(meth.to_s) }
    end

    def all_messages
      Nori.parse(wsdl.xml)[:definitions][:message]
    end
  end
end
