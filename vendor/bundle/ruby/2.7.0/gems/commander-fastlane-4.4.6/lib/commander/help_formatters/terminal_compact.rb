require 'erb'

module Commander
  module HelpFormatter
    class TerminalCompact < Terminal
      def template(name)
        ERB.new(File.read(File.join(File.dirname(__FILE__), 'terminal_compact', "#{name}.erb")), nil, '-')
      end
    end
  end
end
