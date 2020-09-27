# -*- encoding: utf-8 -*-
# stub: highline 1.7.10 ruby lib

Gem::Specification.new do |s|
  s.name = "highline".freeze
  s.version = "1.7.10"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["James Edward Gray II".freeze]
  s.date = "2017-11-24"
  s.description = "A high-level IO library that provides validation, type conversion, and more for\ncommand-line interfaces. HighLine also includes a complete menu system that can\ncrank out anything from simple list selection to complete shells with just\nminutes of work.\n".freeze
  s.email = "james@graysoftinc.com".freeze
  s.extra_rdoc_files = ["README.rdoc".freeze, "INSTALL".freeze, "TODO".freeze, "Changelog.md".freeze, "LICENSE".freeze]
  s.files = ["Changelog.md".freeze, "INSTALL".freeze, "LICENSE".freeze, "README.rdoc".freeze, "TODO".freeze]
  s.homepage = "https://github.com/JEG2/highline".freeze
  s.licenses = ["Ruby".freeze]
  s.rdoc_options = ["--title".freeze, "HighLine Documentation".freeze, "--main".freeze, "README".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3".freeze)
  s.rubygems_version = "3.1.2".freeze
  s.summary = "HighLine is a high-level command-line IO library.".freeze

  s.installed_by_version = "3.1.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_development_dependency(%q<code_statistics>.freeze, [">= 0"])
  else
    s.add_dependency(%q<code_statistics>.freeze, [">= 0"])
  end
end
