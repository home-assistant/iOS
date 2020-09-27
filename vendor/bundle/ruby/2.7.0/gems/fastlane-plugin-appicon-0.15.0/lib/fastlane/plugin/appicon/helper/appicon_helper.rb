module Fastlane
  module Helper
    class AppiconHelper
      def self.check_input_image_size(image, size)
        UI.user_error!("Minimum width of input image should be #{size}") if image.width < size
        UI.user_error!("Minimum height of input image should be #{size}") if image.height < size
        UI.user_error!("Input image should be square") if image.width != image.height
      end

      def self.get_needed_icons(devices, needed_icons, is_android = false, custom_sizes = {})
        icons = []
        devices.each do |device|
          needed_icons[device].each do |scale, sizes|
            sizes.each do |size|
              if size.kind_of?(Array)
                size, role, subtype = size
              end

              if is_android
                width, height = size.split('x').map { |v| v.to_f }
              else
                multiple = device.match(/universal/) ? 1 : scale.to_i
                width, height = size.split('x').map { |v| v.to_f * multiple }
              end

              icons << {
                'width' => width,
                'height' => height,
                'size' => size,
                'device' => device.to_s.gsub('_', '-'),
                'scale' => scale,
                'role' => role,
                'subtype' => subtype
              }

            end
          end
        end

        # Add custom icon sizes (probably for notifications)
        custom_sizes.each do |path, size|
          path = path.to_s
          width, height = size.split('x').map { |v| v.to_f }

          icons << {
            'width' => width,
            'height' => height,
            'size' => size,
            'basepath' => File.dirname(path),
            'filename' => File.basename(path)
          }
        end

        # Sort from the largest to the smallest needed icon
        icons = icons.sort_by {|value| value['width']} .reverse
      end
    end
  end
end
