require 'curb'
require 'environment'

module Yieldmanager2
  class Builder
    def pull_local_copies
      Services.each do |svc|
        print Curl::Easy.perform("#{ApiBase}/#{svc}.php?wsdl").body_str
        break
      end
    end
  end
end
