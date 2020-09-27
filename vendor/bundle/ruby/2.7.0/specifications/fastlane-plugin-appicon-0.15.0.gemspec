# -*- encoding: utf-8 -*-
# stub: fastlane-plugin-appicon 0.15.0 ruby lib

Gem::Specification.new do |s|
  s.name = "fastlane-plugin-appicon".freeze
  s.version = "0.15.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Boris Bu\u0308gling".freeze, "Felix Krause".freeze]
  s.date = "2020-04-28"
  s.email = "boris@icculus.org".freeze
  s.homepage = "https://github.com/fastlane-community/fastlane-plugin-appicon".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.2".freeze
  s.summary = "Generate required icon sizes and iconset from a master application icon.".freeze

  s.installed_by_version = "3.1.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<mini_magick>.freeze, [">= 4.9.4", "< 5.0.0"])
    s.add_runtime_dependency(%q<json>.freeze, [">= 0"])
    s.add_development_dependency(%q<pry>.freeze, [">= 0"])
    s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_development_dependency(%q<rake>.freeze, [">= 0"])
    s.add_development_dependency(%q<rubocop>.freeze, [">= 0"])
    s.add_development_dependency(%q<fastlane>.freeze, [">= 1.95.0"])
  else
    s.add_dependency(%q<mini_magick>.freeze, [">= 4.9.4", "< 5.0.0"])
    s.add_dependency(%q<json>.freeze, [">= 0"])
    s.add_dependency(%q<pry>.freeze, [">= 0"])
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<rspec>.freeze, [">= 0"])
    s.add_dependency(%q<rake>.freeze, [">= 0"])
    s.add_dependency(%q<rubocop>.freeze, [">= 0"])
    s.add_dependency(%q<fastlane>.freeze, [">= 1.95.0"])
  end
end
