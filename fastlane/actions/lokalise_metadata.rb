module Fastlane
  module Actions

    class LokaliseMetadataAction < Action
      @params
      def self.run(params)
        @params = params
        action = params[:action]

        case action
        when "update_itunes"
          key_file = metadata_key_file_itunes()
          metadata = get_metadata_from_lokalise_itunes()
          run_deliver_action(metadata)
        when "update_googleplay"
          release_number = params[:release_number]
          UI.user_error! "Release number is required when using `update_googleplay` action (should be an integer and greater that 0)" unless (release_number and release_number.is_a?(Integer) and release_number > 0)
          key_file = metadata_key_file_googleplay
          metadata = get_metadata_from_lokalise_googleplay()
          save_metadata_to_files(metadata, release_number)
          run_supply_action(params[:validate_only])
        when "update_lokalise_itunes"
          metadata = get_metadata_itunes_connect()
          add_languages = params[:add_languages]
          override_translation = params[:override_translation]
          if add_languages == true
            create_languages(metadata.keys, true)
          end
          if override_translation == true
            upload_metadata_itunes(metadata) unless metadata.empty?
          else
            lokalise_metadata = get_metadata_from_lokalise_itunes()
            filtered_metadata = filter_metadata(metadata, lokalise_metadata)
            upload_metadata_itunes(filtered_metadata) unless filtered_metadata.empty?
          end
        when "update_lokalise_googleplay"
          metadata = get_metadata_google_play()
          add_languages = params[:add_languages]
          override_translation = params[:override_translation]
          if add_languages == true
            create_languages(metadata.keys, false)
          end
          if override_translation == true
            upload_metadata_google_play(metadata) unless metadata.empty?
          else
            lokalise_metadata = get_metadata_from_lokalise_googleplay()
            filtered_metadata = filter_metadata(metadata, lokalise_metadata)
            upload_metadata_google_play(filtered_metadata) unless filtered_metadata.empty?
          end
        end
      end

      def self.create_languages(languages, for_itunes)
        data = {
          iso: languages.map { |language| fix_language_name(language, for_itunes, true) } .to_json
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

        metadata_key_file_itunes().each { |key, parameter|
          final_translations = {}

          metadata.each { |lang, translations|
            if translations.empty? == false
              translation = translations[key]
              final_translations[lang] = translation if translation != nil && translation.empty? == false
            end
          }

          config[parameter.to_sym] = final_translations
        }

        Actions::DeliverAction.run(config)
      end

      def self.run_supply_action(validate_only)
        config = FastlaneCore::Configuration.create(Actions::SupplyAction.available_options, {})
        config[:skip_upload_apk] = true
        config[:skip_upload_aab] = true
        config[:skip_upload_screenshots] = true
        config[:skip_upload_images] = true
        config[:validate_only] = validate_only

        Actions::SupplyAction.run(config)
      end

      def self.save_metadata_to_files(metadata, release_number)

        translations = {}

        metadata_key_file_googleplay().each { |key, parameter|
          final_translations = {}

          metadata.each { |lang, translations|
            if translations.empty? == false
              translation = translations[key]
              final_translations[lang] = translation if translation != nil && translation.empty? == false
            end
          }

          translations[parameter.to_sym] = final_translations
        }

        FileUtils.rm_rf(Dir['fastlane/metadata/android/*'])

        translations.each { |key, parameter|
          parameter.each { |lang, text|
            path = "fastlane/metadata/android/#{lang}/#{key}.txt"
            if "#{key}" ==  "changelogs"
              path = "fastlane/metadata/android/#{lang}/changelogs/#{release_number}.txt"
            end
            dirname = File.dirname(path)
            unless File.directory?(dirname)
              FileUtils.mkdir_p(dirname)
            end
            File.write(path, text)
          }
        }

      end

      def self.make_request(path, data)
        require 'net/http'

        request_data = {
          api_token: @params[:api_token],
          id: @params[:project_identifier]
        }.merge(data)

        uri = URI("https://api.lokalise.com/api/#{path}")
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(request_data)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        response = http.request(request)

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

      def self.upload_metadata(metadata_keys, for_itunes, metadata)

        keys = []

        metadata_keys.each do |key, value|
          key = make_key_object_from_metadata(key, metadata, for_itunes)
          if key
            keys << key
          end
        end

        data = {
          data: keys.to_json
        }

        make_request("string/set", data)
      end

      def self.upload_metadata_itunes(metadata)
        upload_metadata(metadata_key_file_itunes, true, metadata)
      end

      def self.upload_metadata_google_play(metadata)
        upload_metadata(metadata_key_file_googleplay, false, metadata)
      end

      def self.make_key_object_from_metadata(key, metadata, for_itunes)
        key_data = {
          "key" => key,
          "platform_mask" => 16,
          "translations" => {}
        }
        metadata.each { |iso_code, data|
          translation = data[key]
          unless translation == nil || translation.empty?
            key_data["translations"][fix_language_name(iso_code, for_itunes, true)] = translation
          end
        }
        unless key_data["translations"].empty?
          return key_data
        else
          return nil
        end
      end

      def self.get_metadata_google_play()
        available_languages = google_play_languages
        return get_metadata(available_languages, "fastlane/metadata/android/", false)
      end

      def self.get_metadata_itunes_connect()
        available_languages = itunes_connect_languages
        return get_metadata(available_languages, "fastlane/metadata/", true)
      end

      def self.get_metadata(available_languages, folder, for_itunes)
        complete_metadata = {}

        available_languages.each { |iso_code|
          language_directory = "#{folder}#{iso_code}"
          if Dir.exist? language_directory
            language_metadata = {}
            if for_itunes
              metadata_key_file_itunes().each { |key, file|
                populate_hash_key_from_file(language_metadata, key, language_directory + "/#{file}.txt")
              }
            else
              metadata_key_file_googleplay().each { |key, file|
                if file == "changelogs"
                  changelog_directory = "#{folder}#{iso_code}/changelogs"
                  files = Dir.entries("#{changelog_directory}")
                  collectedFiles = files.collect { |s| s.partition(".").first.to_i }
                  sortedFiles = collectedFiles.sort
                  populate_hash_key_from_file(language_metadata, key, language_directory + "/changelogs/#{sortedFiles.last}.txt")
                else
                  populate_hash_key_from_file(language_metadata, key, language_directory + "/#{file}.txt")
                end
              }
            end
            complete_metadata[iso_code] = language_metadata
          end
        }

        return complete_metadata
      end

      def self.get_metadata_from_lokalise(valid_keys, for_itunes)

        data = {
          platform_mask: 16,
          keys: valid_keys.to_json,
        }

        response = make_request("string/list", data)

        if for_itunes
          valid_languages = itunes_connect_languages_in_lokalise()
        else
          valid_languages = google_play_languages_in_lokalise()
        end
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
              metadata[fix_language_name(lang, for_itunes)] = translations
            end
          end
        }
        return metadata

      end

      def self.get_metadata_from_lokalise_itunes()

        valid_keys = metadata_keys_itunes()
        return get_metadata_from_lokalise(valid_keys, true)

      end

      def self.get_metadata_from_lokalise_googleplay()

        valid_keys = metadata_keys_googleplay()
        return get_metadata_from_lokalise(valid_keys, false)

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

      def self.metadata_keys_itunes()
        return metadata_key_file_itunes().keys
      end

      def self.metadata_keys_googleplay()
        return metadata_key_file_googleplay().keys
      end

      def self.metadata_key_file_itunes()
        return {
          "appstore.app.name" => "name",
          "appstore.app.description" => "description",
          "appstore.app.keywords" => "keywords",
          "appstore.app.promotional_text" => "promotional_text",
          "appstore.app.release_notes" => "release_notes",
          "appstore.app.subtitle" => "subtitle",
        }
      end

      def self.metadata_key_file_googleplay()
        return {
          "googleplay.app.title" => "title",
          "googleplay.app.full_description" => "full_description",
          "googleplay.app.short_description" => "short_description",
          "googleplay.app.changelogs" => "changelogs",
        }
      end

      def self.itunes_connect_languages_in_lokalise()
        return itunes_connect_languages().map { |lang|
          fix_language_name(lang, true, true)
        }
      end

      def self.google_play_languages_in_lokalise()
        return google_play_languages().map { |lang|
          fix_language_name(lang, false, true)
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
          "vi"
        ]
      end

      def self.google_play_languages()
        return [
          'af',
          'am',
          'ar',
          'hy',
          'az-AZ',
          'eu-ES',
          'be',
          'bn-BD',
          'bg',
          'my',
          'ca',
          'zh-CN',
          'zh-TW',
          'zh-HK',
          'hr',
          'cs',
          'da',
          'nl-NL',
          'en-AU',
          'en-CA',
          'en-IN',
          'en-SG',
          'en-ZA',
          'en-GB',
          'en-US',
          'et-EE',
          'fil',
          'fi',
          'fr-CA',
          'fr-FR',
          'gl-ES',
          'ka-GE',
          'de-DE',
          'el-GR',
          'he',
          'hi-IN',
          'hu',
          'is-IS',
          'id',
          'it-IT',
          'ja',
          'kn-IN',
          'km-KH',
          'ko',
          'ky',
          'lo',
          'lv-LV',
          'lt-LT',
          'mk-MK',
          'ms',
          'ml-IN',
          'mr',
          'mn-MN',
          'ne-NP',
          'no',
          'no-NO',
          'fa',
          'pl',
          'pt-BR',
          'pt-PT',
          'ro',
          'ru-RU',
          'sr',
          'si',
          'sk',
          'sl-SI',
          'es-419',
          'es-ES',
          'es-US',
          'sw',
          'sv-SE',
          'ta-IN',
          'te-IN',
          'th',
          'tr',
          'uk',
          'vi',
          'zu'
        ]
      end

      def self.fix_language_name(name, for_itunes, for_lokalise = false)
        if for_itunes
          if for_lokalise
            name =  name.gsub("-","_")
            name = "en" if name == "en_US"
            name = "de" if name == "de_DE"
            name = "es" if name == "es_ES"
            name = "fr" if name == "fr_FR"
          else
            name = name.gsub("_","-")
            name = "en-US" if name == "en"
            name = "de-DE" if name == "de"
            name = "es-ES" if name == "es"
            name = "fr-FR" if name == "fr"
          end
        else
          if for_lokalise
            name =  name.gsub("-","_")
            name = "tr" if name == "tr_TR"
            name = "hy" if name == "hy_AM"
            name = "my" if name == "my_MM"
            name = "ms" if name == "ms_MY"
            name = "cs" if name == "cs_CZ"
            name = "da" if name == "da_DK"
            name = "et_EE" if name == "et"
            name = "fi" if name == "fi_FI"
            name = "he" if name == "iw_IL"
            name = "hu" if name == "hu_HU"
            name = "ja" if name == "ja_JP"
            name = "ko" if name == "ko_KR"
            name = "ky" if name == "ky_KG"
            name = "lo" if name == "lo_LA"
            name = "lv_LV" if name == "lv"
            name = "lt_LT" if name == "lt"
            name = "mr" if name == "mr_IN"
            name = "no" if name == "no_NO"
            name = "pl" if name == "pl_PL"
            name = "si" if name == "si_LK"
            name = "sl_SI" if name == "sl"
          else
            name = name.gsub("_","-")
            name = "tr-TR" if name == "tr"
            name = "hy-AM" if name == "hy"
            name = "my-MM" if name == "my"
            name = "ms-MY" if name == "ms"
            name = "cs-CZ" if name == "cs"
            name = "da-DK" if name == "da"
            name = "et" if name == "et-EE"
            name = "fi-FI" if name == "fi"
            name = "iw-IL" if name == "he"
            name = "hu-HU" if name == "hu"
            name = "ja-JP" if name == "ja"
            name = "ko-KR" if name == "ko"
            name = "ky-KG" if name == "ky"
            name = "lo-LA" if name == "lo"
            name = "lv" if name == "lv-LV"
            name = "lt" if name == "lt-LT"
            name = "mr-IN" if name == "mr"
            name = "no-NO" if name == "no"
            name = "pl-PL" if name == "pl"
            name = "si-LK" if name == "si"
            name = "sl" if name == "sl-SI"
          end
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
        "This action scans fastlane/metadata folder and uploads metadata to lokalise.com"
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
                                       description: "Action to perform (can be update_lokalise_itunes or update_lokalise_googleplay or update_itunes or update_googleplay)",
                                       optional: false,
                                       is_string: true,
                                       verify_block: proc do |value|
                                         UI.user_error! "Action should be update_lokalise_googleplay or update_lokalise_itunes or update_itunes or update_googleplay" unless ["update_lokalise_itunes", "update_lokalise_googleplay", "update_itunes", "update_googleplay"].include? value
                                       end),
          FastlaneCore::ConfigItem.new(key: :release_number,
                                      description: "Release number is required to update google play",
                                      optional: true,
                                      is_string: false),
          FastlaneCore::ConfigItem.new(key: :validate_only,
                                      description: "Only validate the metadata (works with only update_googleplay action)",
                                      optional: true,
                                      is_string: false,
                                      default_value: false,
                                      verify_block: proc do |value|
                                        UI.user_error! "Validate only should be true or false" unless [true, false].include? value
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
