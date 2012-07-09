# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "yieldmanager2/version"

Gem::Specification.new do |s|
  s.name        = "yieldmanager2"
  s.version     = Yieldmanager2::VERSION
  s.authors     = ["Bill Gathen"]
  s.email       = ["bill@billgathen.com"]
  s.homepage    = ""
  s.summary     = %q{Rewrite of Yieldmanager gem using Savon}
  s.description = %q{Rewrite of Yieldmanager gem using Savon}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_runtime_dependency "rest-client"

  s.add_runtime_dependency "savon"
  s.add_runtime_dependency "nori"
  s.add_runtime_dependency "nokogiri"
  s.add_development_dependency "rake"
  s.add_development_dependency "curb"
  s.add_development_dependency "rspec"
  s.add_development_dependency "vcr"
  s.add_development_dependency "webmock"
end
