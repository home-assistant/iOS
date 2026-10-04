source 'https://rubygems.org'

gem 'fastlane', '2.240.1'
gem 'rubocop', require: false

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
# rubocop:disable-next Security/Eval
eval(File.read(plugins_path), binding) if File.exist?(plugins_path)
