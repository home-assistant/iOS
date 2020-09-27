require 'mini_magick'

module Fastlane
  module Actions
    class AndroidAppiconAction < Action

      def self.needed_icons
        {
          launcher: {
            :ldpi => ['36x36'],
            :mdpi => ['48x48'],
            :hdpi => ['72x72'],
            :xhdpi => ['96x96'],
            :xxhdpi => ['144x144'],
            :xxxhdpi => ['192x192']
          },
          notification: {
            :ldpi => ['18x18'],
            :mdpi => ['24x24'],
            :hdpi => ['36x36'],
            :xhdpi => ['48x48'],
            :xxhdpi => ['72x72'],
            :xxxhdpi => ['96x96'],
          },
          splash_land: {
            'land-ldpi' => ['320x200'],
            'land-mdpi' => ['480x320'],
            'land-hdpi' => ['800x480'],
            'land-xhdpi' => ['1280x720'],
            'land-xxhdpi' => ['1600x960'],
            'land-xxxhdpi' => ['1920x1280']
          },
          splash_port: {
            'port-ldpi' => ['200x320'],
            'port-mdpi' => ['320x480'],
            'port-hdpi' => ['480x800'],
            'port-xhdpi' => ['720x1280'],
            'port-xxhdpi' => ['960x1600'],
            'port-xxxhdpi' => ['1280x1920']
          }
        }
      end

      def self.run(params)
        fname = params[:appicon_image_file]
        custom_sizes = params[:appicon_custom_sizes]

        icons = Helper::AppiconHelper.get_needed_icons(params[:appicon_icon_types], self.needed_icons, true, custom_sizes)
        icons.each do |icon|
          image = MiniMagick::Image.open(fname)

          Helper::AppiconHelper.check_input_image_size(image, 1024)

          # Custom icons will have basepath and filename already defined
          if icon.has_key?('basepath') && icon.has_key?('filename')
            basepath = Pathname.new(icon['basepath'])
            filename = icon['filename']
          else
            basepath = Pathname.new("#{params[:appicon_path]}-#{icon['scale']}")
            filename = "#{params[:appicon_filename]}.png"
          end

          width_height = [icon['width'], icon['height']].map(&:to_i)
          width, height = width_height
          max = width_height.max

          image.format 'png'
          image.resize "#{max}x#{max}"

          unless width == height
            offset =
            if width > height
              "+0+#{(width - height) / 2}"
            elsif height > width
              "+#{(height - width) / 2}+0"
            end

            image.crop "#{icon['size']}#{offset}"
          end

          FileUtils.mkdir_p(basepath)
          image.write basepath + filename

          if basepath.to_s.match("port-")
            default_portrait_path = basepath.to_s.gsub("port-","")
            FileUtils.mkdir_p(default_portrait_path)
            image.write default_portrait_path + '/' + filename
          end

          if params[:generate_rounded]
            rounded_image = MiniMagick::Image.open(fname)
            rounded_image.format 'png'
            rounded_image.resize "#{width}x#{height}"
            rounded_image = round(rounded_image)
            rounded_image.write basepath + filename.gsub('.png', '_round.png')
          end
        end

        UI.success("Successfully stored launcher icons at '#{params[:appicon_path]}'")
      end

      def self.round(img)
        require 'mini_magick'
        img.format 'png'

        width = img[:width]-2
        radius = width/2

        mask = ::MiniMagick::Image.open img.path
        mask.format 'png'

        mask.combine_options do |m|
          m.alpha 'transparent'
          m.background 'none'
          m.fill 'white'
          m.draw 'roundrectangle 1,1,%s,%s,%s,%s' % [width, width, radius, radius]
        end

        masked = img.composite(mask, 'png') do |i|
          i.alpha "set"
          i.compose 'DstIn'
        end

        return masked
      end

      def self.get_custom_sizes(image, custom_sizes)

      end

      def self.description
        "Generate required icon sizes from a master application icon"
      end

      def self.authors
        ["@adrum"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :appicon_image_file,
                                  env_name: "APPICON_IMAGE_FILE",
                               description: "Path to a square image file, at least 512x512",
                                  optional: false,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :appicon_icon_types,
                                  env_name: "APPICON_ICON_TYPES",
                             default_value: [:launcher],
                               description: "Array of device types to generate icons for",
                                  optional: true,
                                      type: Array),
          FastlaneCore::ConfigItem.new(key: :appicon_path,
                                  env_name: "APPICON_PATH",
                             default_value: 'app/res/mipmap',
                               description: "Path to res subfolder",
                                  optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :appicon_filename,
                                  env_name: "APPICON_FILENAME",
                             default_value: 'ic_launcher',
                               description: "The output filename of each image",
                                  optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :appicon_custom_sizes,
                               description: "Hash of custom sizes - {'path/icon.png' => '256x256'}",
                             default_value: {},
                                  optional: true,
                                      type: Hash),
          FastlaneCore::ConfigItem.new(key: :generate_rounded,
                               description: "Generate round icons?",
                             default_value: false,
                                      type: Boolean)
        ]
      end

      def self.is_supported?(platform)
        [:android].include?(platform)
      end
    end
  end
end
