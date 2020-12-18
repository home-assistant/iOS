module Fastlane
  module Actions

    class AddKeysToLokaliseAction < Action
      def self.run(params)
        require 'net/http'

        token = params[:api_token]
        project_identifier = params[:project_identifier]
        keys = params[:keys]
        platform_mask = params[:platform_mask]

        keysObjects = []

        keys.each do |key|
          keysObjects << {
            key: key,
            platform_mask: platform_mask
          }
        end

        request_data = {
          api_token: token,
          id: project_identifier,
          data: keysObjects.to_json
        }

        uri = URI("https://api.lokalise.com/api/string/set")
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(request_data)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        response = http.request(request)

        jsonResponse = JSON.parse(response.body)
        raise "Bad response 🉐\n#{response.body}".red unless jsonResponse.kind_of? Hash
        if jsonResponse["response"]["status"] == "success"  then
          inserted = jsonResponse["result"]["inserted"]
          updated = jsonResponse["result"]["updated"]
          Helper.log.info "Keys uploaded. #{inserted} inserted and #{updated} updated 🚀".green
        elsif jsonResponse["response"]["status"] == "error"
          code = jsonResponse["response"]["code"]
          message = jsonResponse["response"]["message"]
          raise "Response error code #{code} (#{message}) 📟".red
        else
          raise "Bad response 🉐\n#{jsonResponse}".red
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Add keys to lokalise"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_token,
                                       env_name: "LOKALISE_API_TOKEN",
                                       description: "API Token for Lokalise",
                                       is_string: true,
                                       verify_block: proc do |value|
                                          raise "No API token for Lokalise given, pass using `api_token: 'token'`".red unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :project_identifier,
                                       env_name: "LOKALISE_PROJECT_ID",
                                       description: "Lokalise Project Identifier",
                                       is_string: true,
                                       verify_block: proc do |value|
                                          raise "No Project Identifier for Lokalise given, pass using `project_identifier: 'identifier'`".red unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :platform_mask,
                                       description: "Platform mask where 1 is iOS, 2 is Android, 4 is Web and 16 is Other",
                                       optional: true,
                                       is_string: false,
                                       default_value: 1,
                                       verify_block: proc do |value|
                                          raise "Platfrom mask is an integer value".red unless value.is_a?(Integer)
                                       end),
          FastlaneCore::ConfigItem.new(key: :keys,
                                       description: "Keys to add",
                                       optional: false,
                                       is_string: false,
                                       verify_block: proc do |value|
                                          raise "Keys must be passed as array of strings".red unless (value.kind_of? Array and not value.empty?)
                                          value.each_with_index do |key, index|
                                            raise "Key at index #{index} must be string".red unless key.kind_of? String
                                            raise "Key at index #{index} can't be empty".red if key.empty?
                                          end
                                       end)
        ]
      end

      def self.authors
        "Fedya-L"
      end

      def self.is_supported?(platform)
        [:ios, :mac].include? platform 
      end
    end
  end
end
