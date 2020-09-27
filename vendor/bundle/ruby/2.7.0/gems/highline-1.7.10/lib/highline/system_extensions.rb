# system_extensions.rb
#
#  Created by James Edward Gray II on 2006-06-14.
#  Copyright 2006 Gray Productions. All rights reserved.
#
#  This is Free Software.  See LICENSE and COPYING for details.

require "highline/compatibility"

class HighLine
  module SystemExtensions
    JRUBY = defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'

    if JRUBY
      JRUBY_OVER_17 = JRUBY_VERSION =~ /^1.7/ || JRUBY_VERSION =~ /^9/

      def initialize_system_extensions
        require 'java'
        require 'readline'
        if JRUBY_OVER_17
          java_import 'jline.console.ConsoleReader'

          input = @input && @input.to_inputstream
          output = @output && @output.to_outputstream

          @java_console = ConsoleReader.new(input, output)
          @java_console.set_history_enabled(false)
          @java_console.set_bell_enabled(true)
          @java_console.set_pagination_enabled(false)
          @java_terminal = @java_console.getTerminal
        elsif JRUBY_VERSION =~ /^1.6/
          java_import 'java.io.OutputStreamWriter'
          java_import 'java.nio.channels.Channels'
          java_import 'jline.ConsoleReader'
          java_import 'jline.Terminal'

          @java_input = Channels.newInputStream(@input.to_channel)
          @java_output = OutputStreamWriter.new(Channels.newOutputStream(@output.to_channel))
          @java_terminal = Terminal.getTerminal
          @java_console = ConsoleReader.new(@java_input, @java_output)
          @java_console.setUseHistory(false)
          @java_console.setBellEnabled(true)
          @java_console.setUsePagination(false)
        end
      end
    end

    extend self

    #
    # This section builds character reading and terminal size functions
    # to suit the proper platform we're running on.  Be warned:  Here be
    # dragons!
    #
    if RUBY_PLATFORM =~ /mswin(?!ce)|mingw|bccwin/i
      begin
        require "fiddle"

        module WinAPI
          include Fiddle
          Handle = RUBY_VERSION >= "2.0.0" ? Fiddle::Handle : DL::Handle
          Kernel32 = Handle.new("kernel32")
          Crt = Handle.new("msvcrt") rescue Handle.new("crtdll")

          def self._getch
            @@_m_getch ||= Function.new(Crt["_getch"], [], TYPE_INT)
            @@_m_getch.call
          end

          def self.GetStdHandle(handle_type)
            @@get_std_handle ||= Function.new(Kernel32["GetStdHandle"], [-TYPE_INT], -TYPE_INT)
            @@get_std_handle.call(handle_type)
          end

          def self.GetConsoleScreenBufferInfo(cons_handle, lp_buffer)
            @@get_console_screen_buffer_info ||=
              Function.new(Kernel32["GetConsoleScreenBufferInfo"], [TYPE_LONG, TYPE_VOIDP], TYPE_INT)
            @@get_console_screen_buffer_info.call(cons_handle, lp_buffer)
          end
        end
      rescue LoadError
        require "dl/import"

        module WinAPI
          if defined?(DL::Importer)
            # Ruby 1.9
            extend DL::Importer
          else
            # Ruby 1.8
            extend DL::Importable
          end
          begin
            dlload "msvcrt", "kernel32"
          rescue DL::DLError
            dlload "crtdll", "kernel32"
          end
          extern "unsigned long _getch()"
          extern "unsigned long GetConsoleScreenBufferInfo(unsigned long, void*)"
          extern "unsigned long GetStdHandle(unsigned long)"

          # Ruby 1.8 DL::Importable.import does mname[0,1].downcase so FooBar becomes fooBar
          if defined?(getConsoleScreenBufferInfo)
            alias_method :GetConsoleScreenBufferInfo, :getConsoleScreenBufferInfo
            module_function :GetConsoleScreenBufferInfo
          end
          if defined?(getStdHandle)
            alias_method :GetStdHandle, :getStdHandle
            module_function :GetStdHandle
          end
        end
      end

      CHARACTER_MODE = "Win32API"    # For Debugging purposes only.

      #
      # Windows savvy getc().
      #
      # *WARNING*:  This method ignores <tt>input</tt> and reads one
      # character from +STDIN+!
      #
      def get_character( input = STDIN )
        WinAPI._getch
      end

      # We do not define a raw_no_echo_mode for Windows as _getch turns off echo
      def raw_no_echo_mode
      end

      def restore_mode
      end

      # A Windows savvy method to fetch the console columns, and rows.
      def terminal_size
        format        = 'SSSSSssssSS'
        buf           = ([0] * format.size).pack(format)
        stdout_handle = WinAPI.GetStdHandle(0xFFFFFFF5)

        WinAPI.GetConsoleScreenBufferInfo(stdout_handle, buf)
        _, _, _, _, _,
        left, top, right, bottom, _, _ = buf.unpack(format)
        return right - left + 1, bottom - top + 1
      end
    else                  # If we're not on Windows try...
      begin
        require "termios"             # Unix, first choice termios.

        CHARACTER_MODE = "termios"    # For Debugging purposes only.

        def raw_no_echo_mode
          @state = Termios.getattr(@input)
          new_settings                     =  @state.dup
          new_settings.c_lflag             &= ~(Termios::ECHO | Termios::ICANON)
          new_settings.c_cc[Termios::VMIN] =  1
          Termios.setattr(@input, Termios::TCSANOW, new_settings)
        end

        def restore_mode
          Termios.setattr(@input, Termios::TCSANOW, @state)
        end
      rescue LoadError                # If our first choice fails, try using JLine
        if JRUBY                      # if we are on JRuby. JLine is bundled with JRuby.
          CHARACTER_MODE = "jline"    # For Debugging purposes only.

          def terminal_size
            if JRUBY_OVER_17
              [ @java_terminal.get_width, @java_terminal.get_height ]
            else
              [ @java_terminal.getTerminalWidth, @java_terminal.getTerminalHeight ]
            end
          end

          def raw_no_echo_mode
            @state = @java_console.getEchoCharacter
            @java_console.setEchoCharacter 0
          end

          def restore_mode
            @java_console.setEchoCharacter @state
          end
        else                          # If we are not on JRuby, try ncurses
          begin
            require 'ffi-ncurses'
            CHARACTER_MODE = "ncurses"    # For Debugging purposes only.

            def raw_no_echo_mode
              FFI::NCurses.initscr
              FFI::NCurses.cbreak
            end

            def restore_mode
              FFI::NCurses.endwin
            end

            #
            # A ncurses savvy method to fetch the console columns, and rows.
            #
            def terminal_size
              size = [80, 40]
              FFI::NCurses.initscr
              begin
                size = FFI::NCurses.getmaxyx(FFI::NCurses.stdscr).reverse
              ensure
                FFI::NCurses.endwin
              end
              size
            end
          rescue LoadError            # Finally, if all else fails, use stty
                                      # *WARNING*:  This requires the external "stty" program!
            CHARACTER_MODE = "stty"   # For Debugging purposes only.

            def raw_no_echo_mode
              @state = `stty -g`
              system "stty raw -echo -icanon isig"
            end

            def restore_mode
              system "stty #{@state}"
              print "\r"
            end
          end
        end
      end

      # For termios and stty
      if not method_defined?(:terminal_size)
        # A Unix savvy method using stty to fetch the console columns, and rows.
        # ... stty does not work in JRuby
        def terminal_size
          begin
            require "io/console"
            winsize = IO.console.winsize.reverse rescue nil
            return winsize if winsize
          rescue LoadError
          end

          if /solaris/ =~ RUBY_PLATFORM and
            `stty` =~ /\brows = (\d+).*\bcolumns = (\d+)/
            [$2, $1].map { |x| x.to_i }
          elsif `stty size` =~ /^(\d+)\s(\d+)$/
            [$2.to_i, $1.to_i]
          else
            [ 80, 24 ]
          end
        end
      end
    end

    if not method_defined?(:get_character)
      def get_character( input = STDIN )
        input.getbyte
      end
    end
  end
end
