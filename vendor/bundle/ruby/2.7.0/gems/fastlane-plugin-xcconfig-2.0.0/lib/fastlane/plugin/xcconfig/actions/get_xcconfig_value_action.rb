require 'fastlane/action'
require_relative '../helper/xcconfig_helper'

module Fastlane
  module Actions
    class GetXcconfigValueAction < Action
      def self.run(params)
        path = File.expand_path(params[:path])
        File.read(path).lines.each do |line|
          name, value = Helper::XcconfigHelper.parse_xcconfig_name_value_line(line)
          return value if name == params[:name]
        end

        Fastlane::UI.user_error!("Couldn't read '#{params[:name]}' from #{params[:path]}.")
      end

      def self.description
        'Reads a value of a setting from xcconfig file.'
      end

      def self.authors
        ['Sergii Ovcharenko']
      end

      def self.return_value
        'Value of a setting.'
      end

      def self.details
        'This action reads the value of a given setting from a given xcconfig file. Will throw an error if specified setting doesn\'t exist'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :name,
                                       env_name: "XCCP_GET_VALUE_PARAM_NAME",
                                       description: "Name of key in xcconfig file",
                                       type: String,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :path,
                                       env_name: "XCCP_GET_VALUE_PARAM_PATH",
                                       description: "Path to plist file you want to update",
                                       type: String,
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("Couldn't find xcconfig file at path '#{value}'") unless File.exist?(File.expand_path(value))
                                       end)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
