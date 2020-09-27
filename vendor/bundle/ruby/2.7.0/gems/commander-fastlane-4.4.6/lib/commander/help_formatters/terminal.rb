require 'erb'

module Commander
  module HelpFormatter
    class Terminal < Base
      def render
        template(:help).result(ProgramContext.new(@runner).get_binding)
      end

      def render_command(command)
        template(:command_help).result(Context.new(command).get_binding)
      end

      def template(name)
        ERB.new(File.read(File.join(File.dirname(__FILE__), 'terminal', "#{name}.erb")), nil, '-')
      end
    end
  end
end
