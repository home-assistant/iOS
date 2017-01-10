module Fastlane
  module Actions
    class GitterAction < Action
      def self.run(options)
        require "net/http"
        require "uri"

        uri = URI.parse("https://webhooks.gitter.im/e/#{options[:integration_id]}")
        https = Net::HTTP.new(uri.host, uri.port)
        https.use_ssl = true

        req = Net::HTTP::Post.new(uri.request_uri)

        req.set_form_data({
          "message" => options[:message],
          "level" => options[:level]
        })

        response = https.request(req)

        UI.user_error! "Failed to make a request to Gitter. #{response.message}." unless response.code == "200"
        UI.success "Successfully made a request to Gitter."
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Send events to Gitter.im"
      end

      def self.details
        "Send events to a Gitter.im room which has a custom integration enabled"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :integration_id,
                                       env_name: "FL_GITTER_INTEGRATION_ID",
                                       description: "Gitter integration ID",
                                       sensitive: true,
                                       verify_block: proc do |value|
                                          UI.user_error!("No integration ID for Gitter given, pass using `integration_id: 'token'`") unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :message,
                                       env_name: "FL_GITTER_MESSAGE",
                                       description: "The message to sent to Gitter",
                                       verify_block: proc do |value|
                                          UI.user_error!("No message for Gitter given, pass using `message: 'my message'`") unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :level,
                                       env_name: "FL_GITTER_LEVEL",
                                       description: "The level with which to send the message to Gitter",
                                       default_value: "info")
        ]
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["robbiet480"]
      end

      def self.is_supported?(platform)
        true
      end

      def self.example_code
        [
          'gitter(
            integration_id: "...",
            message: "...",
            level: "info"
          )'
        ]
      end

      def self.category
        :notifications
      end
    end
  end
end
