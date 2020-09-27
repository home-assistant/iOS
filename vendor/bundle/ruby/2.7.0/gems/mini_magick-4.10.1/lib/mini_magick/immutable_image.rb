module MiniMagick
  class Image
    def initialize(source)
      if source.is_a?(String) || source.is_a?(Pathname)
        @source_path = source.to_s
      elsif source.respond_to?(:path)
        @source_path = source.path
      else
        fail ArgumentError, "invalid source object: #{source.inspect} (expected String, Pathname or #path)"
      end
    end

    def method_missing
    end
  end
end

image = MiniMagick::Image.new()
