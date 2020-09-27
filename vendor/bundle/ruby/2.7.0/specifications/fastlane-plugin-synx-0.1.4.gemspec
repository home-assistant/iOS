# -*- encoding: utf-8 -*-
# stub: fastlane-plugin-synx 0.1.4 ruby lib

Gem::Specification.new do |s|
  s.name = "fastlane-plugin-synx".freeze
  s.version = "0.1.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Afonso Gra\u00E7a".freeze]
  s.date = "2020-04-30"
  s.email = "afonso.graca@me.com".freeze
  s.homepage = "https://github.com/afonsograca/fastlane-plugin-synx".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.2".freeze
  s.summary = "Organise your Xcode project folder to match your Xcode groups.".freeze

  s.installed_by_version = "3.1.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<synx>.freeze, [">= 0"])
    s.add_development_dependency(%q<pry>.freeze, [">= 0"])
    s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<rubocop>.freeze, [">= 0"])
    s.add_development_dependency(%q<fastlane>.freeze, [">= 1.94.1"])
  else
    s.add_dependency(%q<synx>.freeze, [">= 0"])
    s.add_dependency(%q<pry>.freeze, [">= 0"])
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rubocop>.freeze, [">= 0"])
    s.add_dependency(%q<fastlane>.freeze, [">= 1.94.1"])
  end
end
