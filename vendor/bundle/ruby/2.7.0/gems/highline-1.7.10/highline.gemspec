# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'highline/version'

GEM_VERSION = HighLine::VERSION

SPEC = Gem::Specification.new do |spec|
  spec.name     = "highline"
  spec.version  = GEM_VERSION
  spec.platform = Gem::Platform::RUBY
  spec.summary  = "HighLine is a high-level command-line IO library."
  spec.files    = `git ls-files`.split("\n")

  spec.test_files       =  `git ls-files -- test/*.rb`.split("\n")
  spec.has_rdoc         =  true
  spec.extra_rdoc_files =  %w[README.rdoc INSTALL TODO Changelog.md LICENSE]
  spec.rdoc_options     << '--title' << 'HighLine Documentation' <<
                           '--main'  << 'README'

  spec.require_path      = 'lib'

  spec.author            = "James Edward Gray II"
  spec.email             = "james@graysoftinc.com"
  spec.rubyforge_project = "highline"
  spec.homepage          = "https://github.com/JEG2/highline"
  spec.license           = "Ruby"
  spec.description       = <<END_DESC
A high-level IO library that provides validation, type conversion, and more for
command-line interfaces. HighLine also includes a complete menu system that can
crank out anything from simple list selection to complete shells with just
minutes of work.
END_DESC

  spec.add_development_dependency "code_statistics"
  spec.required_ruby_version = '>= 1.9.3'
end
