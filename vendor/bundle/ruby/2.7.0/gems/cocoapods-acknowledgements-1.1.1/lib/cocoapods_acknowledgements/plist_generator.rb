require 'redcarpet'

module CocoaPodsAcknowledgements
  class PlistGenerator
    class << self

      def markdown_parser
        @markdown_parser ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      end

      def generate(target_description, sandbox, excluded)
        root_specs = target_description.specs.map(&:root).uniq.reject { |spec| excluded.include?(spec.name) }

        return nil if root_specs.empty?

        specs_metadata = []
        root_specs.each do |spec|
          pod_root = sandbox.pod_dir(spec.name)
          platform = Pod::Platform.new(target_description.platform_name)
          file_accessor = file_accessor(spec, platform, sandbox)
          license_text = license_text(spec, file_accessor)

          spec_metadata = {
            "name" => spec.name,
            "version" => spec.version,
            "authors" => spec.authors,
            "socialMediaURL" => spec.social_media_url,
            "summary" => spec.summary,
            "description" => parse_markdown(spec.description),
            "licenseType" => spec.license[:type],
            "licenseText" => license_text,
            "homepage" => spec.homepage,
          }
          specs_metadata << spec_metadata
        end

        metadata = {}
        metadata["specs"] = specs_metadata
        metadata
      end

      #-----------------------------------------------------------------------#

      def file_accessor(spec, platform, sandbox)
        pod_root = sandbox.pod_dir(spec.name)
        if pod_root.exist?
          path_list = Pod::Sandbox::PathList.new(pod_root)
          Pod::Sandbox::FileAccessor.new(path_list, spec.consumer(platform))
        end
      end

      # Returns the text of the license for the given spec.
      #
      # @param  [Specification] spec
      #         the specification for which license is needed.
      #
      # @return [String] The text of the license.
      # @return [Nil] If not license text could be found.
      #
      def license_text(spec, file_accessor)
        return nil unless spec.license
        text = spec.license[:text]
        unless text
          if file_accessor
            if license_file = file_accessor.license
              if license_file.exist?
                text = IO.read(license_file)
              else
                UI.warn "Unable to read the license file `#{license_file }` " \
                  "for the spec `#{spec}`"
              end
            end
          end
        end
        text
      end

      def parse_markdown(text)
        return nil unless text
        markdown_parser.render(text)
      end

      #-----------------------------------------------------------------------#

    end
  end
end
