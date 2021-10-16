source 'https://rubygems.org'

gem 'cocoapods'
gem 'cocoapods-acknowledgements'
gem 'fastlane'
gem 'rubocop', require: false

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
# rubocop:disable Security/Eval
eval(File.read(plugins_path), binding) if File.exist?(plugins_path)
# rubocop:enable Security/Eval
