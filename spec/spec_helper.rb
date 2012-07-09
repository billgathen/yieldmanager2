$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'yieldmanager2'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures'
  c.hook_into :webmock
  c.configure_rspec_metadata!
end

begin
  require 'spec'
  require 'spec/autorun'
  Spec::Runner.configure do |config|
  end
rescue LoadError
  require 'rspec'
  require 'rspec/autorun'
  RSpec.configure do |config|
  end
end
