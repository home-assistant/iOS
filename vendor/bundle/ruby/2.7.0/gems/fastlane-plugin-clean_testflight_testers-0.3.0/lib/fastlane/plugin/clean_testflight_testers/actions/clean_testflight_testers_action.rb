module Fastlane
  module Actions
    class CleanTestflightTestersAction < Action
      def self.run(params)
        require 'spaceship'

        app_identifier = params[:app_identifier]
        username = params[:username]

        UI.message("Login to iTunes Connect (#{username})")
        Spaceship::Tunes.login(username)
        Spaceship::Tunes.select_team
        UI.message("Login successful")

        UI.message("Fetching all TestFlight testers, this might take a few minutes, depending on the number of testers")

        # Convert from bundle identifier to app ID
        spaceship_app ||= Spaceship::ConnectAPI::App.find(app_identifier)
        UI.user_error!("Couldn't find app '#{app_identifier}' on the account of '#{username}' on iTunes Connect") unless spaceship_app

        all_testers = spaceship_app.get_beta_testers(includes: "betaTesterMetrics", limit: 200)
        counter = 0

        all_testers.each do |current_tester|
          tester_metrics = current_tester.beta_tester_metrics.first

          time = Time.parse(tester_metrics.last_modified_date)
          days_since_status_change = (Time.now - time) / 60.0 / 60.0 / 24.0

          if tester_metrics.beta_tester_state == "INVITED"
            if days_since_status_change > params[:days_of_inactivity]
              remove_tester(current_tester, spaceship_app, params[:dry_run]) # user got invited, but never installed a build... why would you do that?
              counter += 1
            end
          else
            # We don't really have a good way to detect whether the user is active unfortunately
            # So we can just delete users that had no sessions
            if days_since_status_change > params[:days_of_inactivity] && tester_metrics.session_count == 0
              # User had no sessions in the last e.g. 30 days, let's get rid of them
              remove_tester(current_tester, spaceship_app, params[:dry_run])
              counter += 1
            elsif params[:oldest_build_allowed] && tester_metrics.installed_cf_bundle_short_version_string.to_i > 0 && tester_metrics.installed_cf_bundle_short_version_string.to_i < params[:oldest_build_allowed]
              # User has a build that is too old, let's get rid of them
              remove_tester(current_tester, spaceship_app, params[:dry_run])
              counter += 1
            end
          end
        end

        if params[:dry_run]
          UI.success("Didn't delete any testers, but instead only printed them out (#{counter}), disable `dry_run` to actually delete them 🦋")
        else
          UI.success("Successfully removed #{counter} testers 🦋")
        end
      end

      def self.remove_tester(tester, app, dry_run)
        if dry_run
          UI.message("TestFlight tester #{tester.email} seems to be inactive for app ID #{app.id}")
        else
          UI.message("Removing tester #{tester.email} due to inactivity from app ID #{app.id}...")
          tester.delete_from_apps(apps: [app])
        end
      end

      def self.description
        "Automatically remove TestFlight testers that are not actually testing your app"
      end

      def self.authors
        ["KrauseFx"]
      end

      def self.details
        "Automatically remove TestFlight testers that are not actually testing your app"
      end

      def self.available_options
        user = CredentialsManager::AppfileConfig.try_fetch_value(:itunes_connect_id)
        user ||= CredentialsManager::AppfileConfig.try_fetch_value(:apple_id)

        [
          FastlaneCore::ConfigItem.new(key: :username,
                                     short_option: "-u",
                                     env_name: "CLEAN_TESTFLIGHT_TESTERS_USERNAME",
                                     description: "Your Apple ID Username",
                                     default_value: user),
          FastlaneCore::ConfigItem.new(key: :app_identifier,
                                       short_option: "-a",
                                       env_name: "CLEAN_TESTFLIGHT_TESTERS_APP_IDENTIFIER",
                                       description: "The bundle identifier of the app to upload or manage testers (optional)",
                                       optional: true,
                                       default_value: ENV["TESTFLIGHT_APP_IDENTITIFER"] || CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier)),
          FastlaneCore::ConfigItem.new(key: :team_id,
                                       short_option: "-q",
                                       env_name: "CLEAN_TESTFLIGHT_TESTERS_TEAM_ID",
                                       description: "The ID of your iTunes Connect team if you're in multiple teams",
                                       optional: true,
                                       is_string: false, # as we also allow integers, which we convert to strings anyway
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_id),
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_ID"] = value.to_s
                                       end),
          FastlaneCore::ConfigItem.new(key: :team_name,
                                       short_option: "-r",
                                       env_name: "CLEAN_TESTFLIGHT_TESTERS_TEAM_NAME",
                                       description: "The name of your iTunes Connect team if you're in multiple teams",
                                       optional: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_name),
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_NAME"] = value.to_s
                                       end),
          FastlaneCore::ConfigItem.new(key: :days_of_inactivity,
                                     short_option: "-k",
                                     env_name: "CLEAN_TESTFLIGHT_TESTERS_WAIT_PROCESSING_INTERVAL",
                                     description: "Numbers of days a tester has to be inactive for (no build uses) for them to be removed",
                                     default_value: 30,
                                     type: Integer,
                                     verify_block: proc do |value|
                                       UI.user_error!("Please enter a valid positive number of days") unless value.to_i > 0
                                     end),
          FastlaneCore::ConfigItem.new(key: :oldest_build_allowed,
                                     short_option: "-b",
                                     env_name: "CLEAN_TESTFLIGHT_TESTERS_OLDEST_BUILD_ALLOWED",
                                     description: "Oldest build number allowed. All testers with older builds will be removed",
                                     optional: true,
                                     default_value: 0,
                                     type: Integer,
                                     verify_block: proc do |value|
                                       UI.user_error!("Please enter a valid build number") unless value.to_i >= 0
                                     end),
          FastlaneCore::ConfigItem.new(key: :dry_run,
                                     short_option: "-d",
                                     env_name: "CLEAN_TESTFLIGHT_TESTERS_DRY_RUN",
                                     description: "Only print inactive users, don't delete them",
                                     default_value: false,
                                     is_string: false)
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
