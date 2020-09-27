# -*- encoding: utf-8 -*-
# stub: plist 3.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "plist".freeze
  s.version = "3.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ben Bleything".freeze, "Patrick May".freeze]
  s.date = "2018-12-21"
  s.description = "Plist is a library to manipulate Property List files, also known as plists. It can parse plist files into native Ruby data structures as well as generating new plist files from your Ruby objects.".freeze
  s.homepage = "https://github.com/patsplat/plist".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.2".freeze
  s.summary = "All-purpose Property List manipulation library".freeze

  s.installed_by_version = "3.1.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<bundler>.freeze, ["~> 1.14"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 10.5"])
    s.add_development_dependency(%q<test-unit>.freeze, ["~> 1.2"])
  else
    s.add_dependency(%q<bundler>.freeze, ["~> 1.14"])
    s.add_dependency(%q<rake>.freeze, ["~> 10.5"])
    s.add_dependency(%q<test-unit>.freeze, ["~> 1.2"])
  end
end
