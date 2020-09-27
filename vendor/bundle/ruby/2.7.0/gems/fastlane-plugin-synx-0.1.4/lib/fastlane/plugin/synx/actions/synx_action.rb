module Fastlane
  module Actions
    class SynxAction < Action
      def self.run(params)
        require 'shellwords'

        Actions.verify_gem!("synx")

        project_path = params[:xcodeproj]
        project_path ||= Dir["*.xcodeproj"].first
        cmd = []
        cmd << "synx"
        cmd << "--prune" if params[:prune]
        cmd << "--no-color" if params[:no_color]
        cmd << "--no-default-exclusions" if params[:no_default_exclusions]
        cmd << "--no-sort-by-name" if params[:no_sort_by_name]
        cmd << "--quiet" if params[:quiet]
        if params[:exclusion]
          Array(params[:exclusion]).each do |exclusion|
            cmd.concat ["--exclusion", exclusion]
          end
        end
        cmd << project_path
        Actions.sh(Shellwords.join(cmd))
      end

      def self.description
        "Organise your Xcode project folder to match your Xcode groups."
      end

      def self.details
        "A command-line tool that reorganizes your Xcode project folder to match your Xcode groups."
      end

      def self.authors
        ["@afonsograca/@AfonsoGraca"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :xcodeproj,
                                       env_name: "FL_SYNX_PROJECT",
                                       description: "Optional, you must specify the path to your main Xcode project if it is not in the project root directory",
                                       optional: true,
                                       is_string: true,
                                       default_value: nil),
          FastlaneCore::ConfigItem.new(key: :prune,
                                       env_name: "FL_SYNX_PRUNE",
                                       description: "Remove source files and image resources that are not referenced by the the xcode project",
                                       optional: true,
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :no_color,
                                       env_name: "FL_SYNX_NO_COLOR",
                                       description: "Remove all color from the output",
                                       optional: true,
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :no_default_exclusions,
                                       env_name: "FL_SYNX_NO_DEFAULT_EXCLUSIONS",
                                       description: "Do not use the default exclusions of /Libraries, /Frameworks, and /Products",
                                       optional: true,
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :no_sort_by_name,
                                       env_name: "FL_SYNX_NO_SORT_BY_NAME",
                                       description: "Disable sorting groups by name",
                                       optional: true,
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :quiet,
                                       env_name: "FL_SYNX_QUIET",
                                       description: "Silence all output",
                                       optional: true,
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :exclusion,
                                       env_name: "FL_SYNX_EXCLUSION",
                                       description: "Ignore an Xcode group while syncing",
                                       optional: true,
                                       is_string: false,
                                       default_value: nil)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
