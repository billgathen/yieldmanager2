# Updates currently broken: for informational purposes only! Use at your own risk!

# Why yieldmanager2? Why not just go 1.0 with [the existing gem](http://github.com/billgathen/yieldmanager)?

Backward-compatibility. I'd gotten most of the way down the road of a complete rewrite,
ditching soap4r and hpricot (both stone-dead projects), when I realized that supporting
the object-oriented return style that soap4r gave me for free would be very ticklish and
fraught with error. However, I personally have *so much* code out there based on this
style that I couldn't just cut the legs out from under it. Therefore, I'll be continuing
to update when API versions sunset, as I have been, but this gem will get all feature
enhancements. The original gem also won't get any more hacks to run under 1.9, because
that's what this gem is for.

Now the good news:
* Use any API version you like. No more forced updates, unless a service you want gets added.
* Uses environment variables as login defaults, or you can supply them explicitly
* VCR-compatible
* No more naming collisions with ActiveRecord objects
* Designed from the ground-up for 1.9 (if it works for you under 1.8.7, cool)
* No more soap4r (replaced by savon)
* No more hpricot (replaced by nokogiri)

Enjoy!

# yieldmanager

This gem offers read/write access to [YieldManager's API tools](https://api.yieldmanager.com/doc/) and
ad-hoc reporting through the Reportware tool.

It pulls a fresh wsdl from the api.yieldmanager.com site the first time you use a service
and re-uses that wsdl for the life of the Yieldmanager2::Client object.

### Installation

Yieldmanager2 is available as a gem for easy installation.

	sudo gem install yieldmanager2

or if you're using [RVM](https://rvm.beginrescueend.com/) (and why on earth wouldn't you?)

	gem install yieldmanager2
	
The project is available for review/forking on github.com
	
	git clone git://github.com/billgathen/yieldmanager2.git

To use in a Rails project, add this to config/environment.rb:

	config.gem 'yieldmanager2'

### Creating a Yieldmanager2::Client

The easiest method is allowing your environment variables to supply all config details:
* YIELDMANAGER_USER
* YIELDMANAGER_PASS
* YIELDMANAGER_API_VERSION
* YIELDMANAGER_ENV # or let this default to 'prod'

Allowing you do this:

	require 'yieldmanager2'

	@ym = Yieldmanager2::Client.new

...and allowing you to keep your login details out of your project (as it should have been from the start).

Explicit args still work:

	require 'yieldmanager2'
	
	@ym = Yieldmanager2::Client.new(
		:user => "bob",
		:pass => "secret"
		:api_version => "1.34"
	)
	
The default environment is production.
To access the test environment, use this:

	@ym = Yieldmanager2::Client.new(
		:user => "bob",
		:pass => "secret"
		:api_version => "1.34",
		:env => "test"
	)

The keys can also be passed as strings: 'user', 'pass', 'api_version' and 'env'.

**NOTE** Changing the environment after creation has no effect!

### Finding available services

	@ym.available_services

### Using a service

	@ym.session do |token|
		@currencies = @ym.dictionary.getCurrencies(token)
	end
	
### Pagination

Some calls return datasets too large to retrieve all at once.
Pagination allows you to pull them back incrementally, handling
the partial dataset on-the-fly or accumulating it for later use.

	BLOCK_SIZE = 50
	id = 1
	@ym.session do |token|
		@ym.paginate(BLOCK_SIZE) do |block|
			(lines,tot) = @ym.line_item.getByBuyer(token,id,BLOCK_SIZE,block)
			# ...do something with lines...
			tot # remember to return total!
		end
	end


### Pulling reports

Accessing reportware assumes you've used the "Get request XML"
functionality in the UI to get your request XML, or have
crafted one from scratch. Assuming it's in a variable called
**request_xml**, you'd access the data this way:

	@ym.session do |token|
		report = @ym.pull_report(token, request_xml)
		puts report.headers.join("\t")
		report.data.each do |row|
			puts row.join("\t")
		end
	end

Column data can be accessed either by index or column name:

	report.headers # => ['advertiser_name','seller_imps']
	report.data[0][0] # => "Bob's Ads"
	report.data[0].by_name('advertiser_name') # => "Bob's Ads"
	report.data[0].by_name(:advertiser_name) # => "Bob's Ads"

If you call **by_name** with a non-existent column, it will throw an
**ArgumentError** telling you so.

Or you can extract the report to an array of named hashes, removing
dependencies on the gem for consumers of the data (say, across an API):

	hashes = report.to_hashes
	hashes[0]['advertiser_name'] # => "Bob's Ads"

**NOTE** Any totals columns your xml requests will be interpreted
as ordinary data.

### Mocking reports

When simulating report calls without actually hitting Yieldmanager, you can
create your own reports.

	rpt = Yieldmanager2::Report.new
	rpt.headers = ["first","second"]
	rpt.add_row([1,2])
	rpt.data.first.by_name("first").should == 1
	rpt.data.first.by_name("second").should == 2

### VCR integration

[VCR](http://github.com/myronmarston/vcr) is a controversial but useful gem that can
massively speed-up a large YM test suite.

To get it working, add both VCR and WebMock as development dependencies in your gemfile:

	group :development, :test do
	  gem "vcr"
	  gem "webmock"
	end

Then include the following in spec_helper.rb:

	require 'vcr'

	VCR.configure do |c|
	  c.cassette_library_dir = 'spec/fixtures'
	  c.hook_into :webmock
	  c.configure_rspec_metadata!
	end

To VCR-enable a spec that hits YM, add ***:vcr => true*** to the spec:

	it "uses VCR to speed things up", :vcr => true do

***NOTE*** If you're hacking on the gem itself and want to force a true rerun, use the rake task:

	rake clear_vcr_cassettes

Take a peek inside the Rakefile to see how to automate clearing the files for your own projects.

### Wiredumps (SOAP logging)

To see the nitty-gritty of what's going over the wire (Yahoo tech support often asks for this),
you can activate a "wiredump" on a per-session basis. Typically you just echo it to standard out.
For instance:

	Savon.configure{ |config| config.log = true }
  client.session do |token|
		adv = client.entity.get(token,12345)
	end
	Savon.configure{ |config| config.log = false }

For Rails in a passenger environment, standard out doesn't end up in the logfiles.
Instead, redirect to a file:

	wiredump_file = "#{Rails.root}/log/wiredump_#{Time.new.strftime('%H%M%S')}.log"
	l = Logger.new(wiredump_file)
	Savon.configure{ |config| config.log = true; config.logger = l }

	client.session do |token|
		adv = client.entity.get(token,12345)
	end

	Savon.configure{ |config| config.log = false }

### session vs. start_session/end_session

The **session** method opens a session, gives you a token to use in your service
calls, then closes the session when the block ends, even if an exception is
raised during processing. It's the recommended method to ensure you don't
hang connections when things go wrong. If you use start/end, make sure you
wrap your logic in a begin/ensure clause and call end_session from the ensure.

## Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Add specs for it. This is important so I don't break it in a future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2009-2012 Bill Gathen. See LICENSE for details.
