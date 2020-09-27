# -*- encoding: utf-8 -*-
# stub: fastlane-plugin-clean_testflight_testers 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "fastlane-plugin-clean_testflight_testers".freeze
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Felix Krause".freeze]
  s.date = "2019-08-05"
  s.email = "testflighttesters@krausefx.com".freeze
  s.homepage = "https://github.com/KrauseFx/fastlane-plugin-clean_testflight_testers".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.2".freeze
  s.summary = "Automatically remove TestFlight testers that are not actually testing your app".freeze

  s.installed_by_version = "3.1.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<pry>.freeze, [">= 0"])
    s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<rubocop>.freeze, [">= 0"])
    s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_development_dependency(%q<fastlane>.freeze, [">= 2.56.0"])
  else
    s.add_dependency(%q<pry>.freeze, [">= 0"])
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rubocop>.freeze, [">= 0"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_dependency(%q<fastlane>.freeze, [">= 2.56.0"])
  end
end
