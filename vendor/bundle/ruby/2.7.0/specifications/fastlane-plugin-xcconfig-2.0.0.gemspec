# -*- encoding: utf-8 -*-
# stub: fastlane-plugin-xcconfig 2.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "fastlane-plugin-xcconfig".freeze
  s.version = "2.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Sergii Ovcharenko".freeze]
  s.date = "2019-05-17"
  s.email = "sergii@sovcharenko.com".freeze
  s.homepage = "https://github.com/sovcharenko/fastlane-plugin-xcconfig".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.2".freeze
  s.summary = "Adds 2 actions to fastlane to read and update xcconfig files.".freeze

  s.installed_by_version = "3.1.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<pry>.freeze, [">= 0"])
    s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec_junit_formatter>.freeze, [">= 0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<rubocop>.freeze, ["= 0.49.1"])
    s.add_development_dependency(%q<rubocop-require_tools>.freeze, [">= 0"])
    s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_development_dependency(%q<fastlane>.freeze, [">= 2.81.0"])
  else
    s.add_dependency(%q<pry>.freeze, [">= 0"])
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_dependency(%q<rspec_junit_formatter>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rubocop>.freeze, ["= 0.49.1"])
    s.add_dependency(%q<rubocop-require_tools>.freeze, [">= 0"])
    s.add_dependency(%q<simplecov>.freeze, [">= 0"])
    s.add_dependency(%q<fastlane>.freeze, [">= 2.81.0"])
  end
end
