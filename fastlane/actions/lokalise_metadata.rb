module Fastlane
  module Actions

    class LokaliseMetadataAction < Action
      @params
      def self.run(params)
        @params = params
        action = params[:action]

        case action
        when "update_itunes"
          key_file = metadata_key_file()
          metadata = get_metadata_from_lokalise()
          run_deliver_action(metadata)
        when "update_lokalise"
          metadata = get_metadata()
          add_languages = params[:add_languages]
          override_translation = params[:override_translation]
          if add_languages == true 
            create_languages(metadata.keys)
          end
          if override_translation == true
            upload_metadata(metadata) unless metadata.empty?
          else
            lokalise_metadata = get_metadata_from_lokalise()
            filtered_metadata = filter_metadata(metadata, lokalise_metadata)
            upload_metadata(filtered_metadata) unless filtered_metadata.empty?
          end
        end

      end

      def self.create_languages(languages)
        data = {
          iso: languages.map { |language| fix_language_name(language, true) } .to_json
        }
        make_request("language/add", data)
      end

      def self.filter_metadata(metadata, other_metadata)
        filtered_metadata = {}
        metadata.each { |language, translations|
          other_translations = other_metadata[language]
          filtered_translations = {}
          
          if other_translations != nil && other_translations.empty? == false
            translations.each { |key, value|
              other_value = other_translations[key]
              filtered_translations[key] = value unless other_value != nil && other_value.empty? == false
            }
          else 
            filtered_translations = translations
          end

          filtered_metadata[language] = filtered_translations unless filtered_translations.empty?
        }
        return filtered_metadata
      end


      def self.run_deliver_action(metadata)
        config = FastlaneCore::Configuration.create(Actions::DeliverAction.available_options, {})
        config.load_configuration_file("Deliverfile")
        config[:metadata_path] = "./fastlane/no_metadata"
        config[:screenshots_path] = "./fastlane/no_screenshot"
        config[:skip_screenshots] = true
        config[:run_precheck_before_submit] = false
        config[:skip_binary_upload] = true
        config[:skip_app_version_update] = true
        config[:force] = true

        metadata_key_file().each { |key, parameter|
          final_translations = {}

          metadata.each { |lang, translations|
            if translations.empty? == false
              translation = translations[key]
              puts translation
              final_translations[lang] = translation if translation != nil && translation.empty? == false
            end 
          }

          config[parameter.to_sym] = final_translations
        }

        Actions::DeliverAction.run(config)
      end

      def self.make_request(path, data)
        require 'net/http'

        request_data = {
          api_token: @params[:api_token],
          id: @params[:project_identifier]
        }.merge(data)

        uri = URI("https://lokalise.co/api/#{path}")
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(request_data)
  
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        response = http.request(request)

        puts request_data
        jsonResponse = JSON.parse(response.body)
        raise "Bad response 🉐\n#{response.body}" unless jsonResponse.kind_of? Hash
        if jsonResponse["response"]["status"] == "success"  then
          UI.success "Response #{jsonResponse} 🚀"
        elsif jsonResponse["response"]["status"] == "error"
          code = jsonResponse["response"]["code"]
          message = jsonResponse["response"]["message"]
          raise "Response error code #{code} (#{message}) 📟"
        else
          raise "Bad response 🉐\n#{jsonResponse}"
        end
        return jsonResponse
      end

      def self.upload_metadata(metadata)
        
        keys = []

        metadata_keys.each do |key, value|
          key = make_key_object_from_metadata(key, metadata)
          if key 
            keys << key
          end
        end

        data = {
          data: keys.to_json
        }

        make_request("string/set", data)
      end

      def self.make_key_object_from_metadata(key, metadata)
        key_data = {
          "key" => key,
          "platform_mask" => 16,
          "translations" => {}
        }
        metadata.each { |iso_code, data|
          translation = data[key]
          unless translation == nil || translation.empty?
            key_data["translations"][fix_language_name(iso_code, true)] = translation
          end
        }
        unless key_data["translations"].empty? 
          return key_data
        else
          return nil
        end
      end

      def self.get_metadata()
        available_languages = itunes_connect_languages
        complete_metadata = {}

        available_languages.each { |iso_code|
          language_directory = "fastlane/metadata/#{iso_code}"
          if Dir.exist? language_directory
            language_metadata = {}
            metadata_key_file().each { |key, file|
              populate_hash_key_from_file(language_metadata, key, language_directory + "/#{file}.txt")
            }
            complete_metadata[iso_code] = language_metadata
          end
        }

        return complete_metadata
      end

      def self.get_metadata_from_lokalise()

        valid_keys = metadata_keys()
        data = {
          platform_mask: 16,
          keys: valid_keys.to_json,
        }

        response = make_request("string/list", data)

        valid_languages = itunes_connect_languages_in_lokalise()        
        metadata = {}

        response["strings"].each { |lang, translation_objects|
          if valid_languages.include?(lang)
            translations = {}
            translation_objects.each { |object|
              key = object["key"]
              translation = object["translation"]
              if valid_keys.include?(key) && translation != nil && translation.empty? == false 
                translations[key] = translation
              end
            }
            if translations.empty? == false
              metadata[fix_language_name(lang)] = translations
            end
          end
        }

        return metadata

      end

      def self.populate_hash_key_from_file(hash, key, filepath)
        begin
          text = File.read filepath
          text.chomp!
          hash[key] = text unless text.empty?
        rescue => exception
          raise exception
        end        
      end

      def self.metadata_keys()
        return metadata_key_file().keys
      end

      def self.metadata_key_file()
        return {
          "appstore.app.name" => "name",
          "appstore.app.description" => "description",
          "appstore.app.keywords" => "keywords",
          "appstore.app.promotional_text" => "promotional_text",
          "appstore.app.release_notes" => "release_notes",
          "appstore.app.subtitle" => "subtitle",
        }
      end

      def self.itunes_connect_languages_in_lokalise()
        return itunes_connect_languages().map { |lang| 
          fix_language_name(lang, true) 
        }
      end

      def self.itunes_connect_languages()
        return [
          "en-US",
          "zh-Hans",
          "zh-Hant",
          "da",
          "nl-NL",
          "en-AU",
          "en-CA",
          "en-GB",
          "fi",
          "fr-FR",
          "fr-CA",
          "de-DE",
          "el",
          "id",
          "it",
          "ja",
          "ko",
          "ms",
          "no",
          "pt-BR",
          "pt-PT",
          "ru",
          "es-MX",
          "es-ES",
          "sv",
          "th",
          "tr",
          "vi",
        ]
      end

      def self.fix_language_name(name, for_lokalise = false)
        if for_lokalise
          name =  name.gsub("-","_")
          name = "en" if name == "en_US"
          name = "de" if name == "de_DE"
        else 
          name = name.gsub("_","-")
          name = "en-US" if name == "en"
          name = "de-DE" if name == "de"
        end
        return name
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Upload metadata to lokalise."
      end

      def self.details
        "This action scans fastlane/metadata folder and uploads metadata to lokalise.co"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_token,
                                       env_name: "LOKALISE_API_TOKEN",
                                       description: "API Token for Lokalise",
                                       verify_block: proc do |value|
                                          UI.user_error! "No API token for Lokalise given, pass using `api_token: 'token'`" unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :project_identifier,
                                       env_name: "LOKALISE_PROJECT_ID",
                                       description: "Lokalise Project ID",
                                       verify_block: proc do |value|
                                          UI.user_error! "No Project Identifier for Lokalise given, pass using `project_identifier: 'identifier'`" unless (value and not value.empty?)
                                       end),
          FastlaneCore::ConfigItem.new(key: :add_languages,
                                       description: "Add missing languages in lokalise",
                                       optional: true,
                                       is_string: false,
                                       default_value: false,
                                       verify_block: proc do |value|
                                         UI.user_error! "Add languages should be true or false" unless [true, false].include? value
                                       end),
          FastlaneCore::ConfigItem.new(key: :override_translation,
                                       description: "Override translations in lokalise",
                                       optional: true,
                                       is_string: false,
                                       default_value: false,
                                       verify_block: proc do |value|
                                         UI.user_error! "Override translation should be true or false" unless [true, false].include? value
                                       end),
          FastlaneCore::ConfigItem.new(key: :action,
                                       description: "Action to perform (can be update_lokalise or update_itunes)",
                                       optional: false,
                                       is_string: true,
                                       verify_block: proc do |value|
                                         UI.user_error! "Action should be update_lokalise or update_itunes" unless ["update_lokalise", "update_itunes"].include? value
                                       end),
        ]
      end

      def self.authors
        ["Fedya-L"]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
