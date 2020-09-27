# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'commander/version'

Gem::Specification.new do |s|
  s.name        = 'commander-fastlane'
  s.version     = Commander::VERSION
  s.authors     = ['TJ Holowaychuk', 'Gabriel Gilder']
  s.email       = ['gabriel@gabrielgilder.com']
  s.license     = 'MIT'
  s.homepage    = 'https://github.com/fastlane/commander'
  s.summary     = 'The complete solution for Ruby command-line executables'
  s.description = 'The complete solution for Ruby command-line executables. Commander bridges the gap between other terminal related libraries you know and love (OptionParser, HighLine), while providing many new features, and an elegant API.'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ['lib']

  s.add_runtime_dependency('highline', '~> 1.7.2')

  s.add_development_dependency('rspec', '~> 3.2')
  s.add_development_dependency('rake')
  s.add_development_dependency('simplecov')
  if RUBY_VERSION < '2.0'
    s.add_development_dependency('rubocop', '~> 0.41.1')
    s.add_development_dependency('json', '< 2.0')
  else
    s.add_development_dependency('rubocop', '~> 0.49.1')
  end
end
