# coding: utf-8
# highline.rb
#
#  Created by James Edward Gray II on 2005-04-26.
#  Copyright 2005 Gray Productions. All rights reserved.
#
# See HighLine for documentation.
#
# This is Free Software.  See LICENSE and COPYING for details.

require "erb"
require "optparse"
require "stringio"
require "abbrev"
require "highline/system_extensions"
require "highline/question"
require "highline/menu"
require "highline/color_scheme"
require "highline/style"
require "highline/version"

#
# A HighLine object is a "high-level line oriented" shell over an input and an
# output stream.  HighLine simplifies common console interaction, effectively
# replacing puts() and gets().  User code can simply specify the question to ask
# and any details about user interaction, then leave the rest of the work to
# HighLine.  When HighLine.ask() returns, you'll have the answer you requested,
# even if HighLine had to ask many times, validate results, perform range
# checking, convert types, etc.
#
class HighLine
  # An internal HighLine error.  User code does not need to trap this.
  class QuestionError < StandardError
    # do nothing, just creating a unique error type
  end

  # The setting used to disable color output.
  @@use_color = true

  # Pass +false+ to _setting_ to turn off HighLine's color escapes.
  def self.use_color=( setting )
    @@use_color = setting
  end

  # Returns true if HighLine is currently using color escapes.
  def self.use_color?
    @@use_color
  end

  # For checking if the current version of HighLine supports RGB colors
  # Usage: HighLine.supports_rgb_color? rescue false   # rescue for compatibility with older versions
  # Note: color usage also depends on HighLine.use_color being set
  def self.supports_rgb_color?
    true
  end

  # The setting used to disable EOF tracking.
  @@track_eof = true

  # Pass +false+ to _setting_ to turn off HighLine's EOF tracking.
  def self.track_eof=( setting )
    @@track_eof = setting
  end

  # Returns true if HighLine is currently tracking EOF for input.
  def self.track_eof?
    @@track_eof
  end

  # The setting used to control color schemes.
  @@color_scheme = nil

  # Pass ColorScheme to _setting_ to set a HighLine color scheme.
  def self.color_scheme=( setting )
    @@color_scheme = setting
  end

  # Returns the current color scheme.
  def self.color_scheme
    @@color_scheme
  end

  # Returns +true+ if HighLine is currently using a color scheme.
  def self.using_color_scheme?
    not @@color_scheme.nil?
  end

  #
  # Embed in a String to clear all previous ANSI sequences.  This *MUST* be
  # done before the program exits!
  #

  ERASE_LINE_STYLE = Style.new(:name=>:erase_line, :builtin=>true, :code=>"\e[K")  # Erase the current line of terminal output
  ERASE_CHAR_STYLE = Style.new(:name=>:erase_char, :builtin=>true, :code=>"\e[P")  # Erase the character under the cursor.
  CLEAR_STYLE      = Style.new(:name=>:clear,      :builtin=>true, :code=>"\e[0m") # Clear color settings
  RESET_STYLE      = Style.new(:name=>:reset,      :builtin=>true, :code=>"\e[0m") # Alias for CLEAR.
  BOLD_STYLE       = Style.new(:name=>:bold,       :builtin=>true, :code=>"\e[1m") # Bold; Note: bold + a color works as you'd expect,
                                                              # for example bold black. Bold without a color displays
                                                              # the system-defined bold color (e.g. red on Mac iTerm)
  DARK_STYLE       = Style.new(:name=>:dark,       :builtin=>true, :code=>"\e[2m") # Dark; support uncommon
  UNDERLINE_STYLE  = Style.new(:name=>:underline,  :builtin=>true, :code=>"\e[4m") # Underline
  UNDERSCORE_STYLE = Style.new(:name=>:underscore, :builtin=>true, :code=>"\e[4m") # Alias for UNDERLINE
  BLINK_STYLE      = Style.new(:name=>:blink,      :builtin=>true, :code=>"\e[5m") # Blink; support uncommon
  REVERSE_STYLE    = Style.new(:name=>:reverse,    :builtin=>true, :code=>"\e[7m") # Reverse foreground and background
  CONCEALED_STYLE  = Style.new(:name=>:concealed,  :builtin=>true, :code=>"\e[8m") # Concealed; support uncommon

  STYLES = %w{CLEAR RESET BOLD DARK UNDERLINE UNDERSCORE BLINK REVERSE CONCEALED}

  # These RGB colors are approximate; see http://en.wikipedia.org/wiki/ANSI_escape_code
  BLACK_STYLE      = Style.new(:name=>:black,      :builtin=>true, :code=>"\e[30m", :rgb=>[  0,  0,  0])
  RED_STYLE        = Style.new(:name=>:red,        :builtin=>true, :code=>"\e[31m", :rgb=>[128,  0,  0])
  GREEN_STYLE      = Style.new(:name=>:green,      :builtin=>true, :code=>"\e[32m", :rgb=>[  0,128,  0])
  BLUE_STYLE       = Style.new(:name=>:blue,       :builtin=>true, :code=>"\e[34m", :rgb=>[  0,  0,128])
  YELLOW_STYLE     = Style.new(:name=>:yellow,     :builtin=>true, :code=>"\e[33m", :rgb=>[128,128,  0])
  MAGENTA_STYLE    = Style.new(:name=>:magenta,    :builtin=>true, :code=>"\e[35m", :rgb=>[128,  0,128])
  CYAN_STYLE       = Style.new(:name=>:cyan,       :builtin=>true, :code=>"\e[36m", :rgb=>[  0,128,128])
  # On Mac OSX Terminal, white is actually gray
  WHITE_STYLE      = Style.new(:name=>:white,      :builtin=>true, :code=>"\e[37m", :rgb=>[192,192,192])
  # Alias for WHITE, since WHITE is actually a light gray on Macs
  GRAY_STYLE       = Style.new(:name=>:gray,       :builtin=>true, :code=>"\e[37m", :rgb=>[192,192,192])
  GREY_STYLE       = Style.new(:name=>:grey,       :builtin=>true, :code=>"\e[37m", :rgb=>[192,192,192])
  # On Mac OSX Terminal, this is black foreground, or bright white background.
  # Also used as base for RGB colors, if available
  NONE_STYLE       = Style.new(:name=>:none,       :builtin=>true, :code=>"\e[38m", :rgb=>[  0,  0,  0])

  BASIC_COLORS = %w{BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE GRAY GREY NONE}

  colors = BASIC_COLORS.dup
  BASIC_COLORS.each do |color|
    bright_color = "BRIGHT_#{color}"
    colors << bright_color
    const_set bright_color+'_STYLE', const_get(color + '_STYLE').bright

    light_color = "LIGHT_#{color}"
    colors << light_color
    const_set light_color+'_STYLE', const_get(color + '_STYLE').light
  end
  COLORS = colors

  colors.each do |color|
    const_set color, const_get("#{color}_STYLE").code
    const_set "ON_#{color}_STYLE", const_get("#{color}_STYLE").on
    const_set "ON_#{color}", const_get("ON_#{color}_STYLE").code
  end
  ON_NONE_STYLE.rgb = [255,255,255] # Override; white background

  STYLES.each do |style|
    const_set style, const_get("#{style}_STYLE").code
  end

  # For RGB colors:
  def self.const_missing(name)
    if name.to_s =~ /^(ON_)?(RGB_)([A-F0-9]{6})(_STYLE)?$/ # RGB color
      on = $1
      suffix = $4
      if suffix
        code_name = $1.to_s + $2 + $3
      else
        code_name = name.to_s
      end
      style_name = code_name + '_STYLE'
      style = Style.rgb($3)
      style = style.on if on
      const_set(style_name, style)
      const_set(code_name, style.code)
      if suffix
        style
      else
        style.code
      end
    else
      raise NameError, "Bad color or uninitialized constant #{name}"
    end
  end

  #
  # Create an instance of HighLine, connected to the streams _input_
  # and _output_.
  #
  def initialize( input = $stdin, output = $stdout,
                  wrap_at = nil, page_at = nil, indent_size=3, indent_level=0 )
    @input   = input
    @output  = output

    @multi_indent = true
    @indent_size = indent_size
    @indent_level = indent_level

    self.wrap_at = wrap_at
    self.page_at = page_at

    @question = nil
    @answer   = nil
    @menu     = nil
    @header   = nil
    @prompt   = nil
    @gather   = nil
    @answers  = nil
    @key      = nil

    initialize_system_extensions if respond_to?(:initialize_system_extensions)
  end

  include HighLine::SystemExtensions

  # The current column setting for wrapping output.
  attr_reader :wrap_at
  # The current row setting for paging output.
  attr_reader :page_at
  # Indentation over multiple lines
  attr_accessor :multi_indent
  # The indentation size
  attr_accessor :indent_size
  # The indentation level
  attr_accessor :indent_level

  #
  # A shortcut to HighLine.ask() a question that only accepts "yes" or "no"
  # answers ("y" and "n" are allowed) and returns +true+ or +false+
  # (+true+ for "yes").  If provided a +true+ value, _character_ will cause
  # HighLine to fetch a single character response. A block can be provided
  # to further configure the question as in HighLine.ask()
  #
  # Raises EOFError if input is exhausted.
  #
  def agree( yes_or_no_question, character = nil )
    ask(yes_or_no_question, lambda { |yn| yn.downcase[0] == ?y}) do |q|
      q.validate                 = /\Ay(?:es)?|no?\Z/i
      q.responses[:not_valid]    = 'Please enter "yes" or "no".'
      q.responses[:ask_on_error] = :question
      q.character                = character

      yield q if block_given?
    end
  end

  #
  # This method is the primary interface for user input.  Just provide a
  # _question_ to ask the user, the _answer_type_ you want returned, and
  # optionally a code block setting up details of how you want the question
  # handled.  See HighLine.say() for details on the format of _question_, and
  # HighLine::Question for more information about _answer_type_ and what's
  # valid in the code block.
  #
  # If <tt>@question</tt> is set before ask() is called, parameters are
  # ignored and that object (must be a HighLine::Question) is used to drive
  # the process instead.
  #
  # Raises EOFError if input is exhausted.
  #
  def ask( question, answer_type = nil, &details ) # :yields: question
    @question ||= Question.new(question, answer_type, &details)

    return gather if @question.gather

    # readline() needs to handle its own output, but readline only supports
    # full line reading.  Therefore if @question.echo is anything but true,
    # the prompt will not be issued. And we have to account for that now.
    # Also, JRuby-1.7's ConsoleReader.readLine() needs to be passed the prompt
    # to handle line editing properly.
    say(@question) unless ((JRUBY or @question.readline) and (@question.echo == true and @question.limit.nil?))

    begin
      @answer = @question.answer_or_default(get_response)
      unless @question.valid_answer?(@answer)
        explain_error(:not_valid)
        raise QuestionError
      end

      @answer = @question.convert(@answer)

      if @question.in_range?(@answer)
        if @question.confirm
          # need to add a layer of scope to ask a question inside a
          # question, without destroying instance data
          context_change = self.class.new(@input, @output, @wrap_at, @page_at, @indent_size, @indent_level)
          if @question.confirm == true
            confirm_question = "Are you sure?  "
          else
            # evaluate ERb under initial scope, so it will have
            # access to @question and @answer
            template  = ERB.new(@question.confirm, nil, "%")
            confirm_question = template.result(binding)
          end
          unless context_change.agree(confirm_question)
            explain_error(nil)
            raise QuestionError
          end
        end

        @answer
      else
        explain_error(:not_in_range)
        raise QuestionError
      end
    rescue QuestionError
      retry
    rescue ArgumentError, NameError => error
      raise if error.is_a?(NoMethodError)
      if error.message =~ /ambiguous/
        # the assumption here is that OptionParser::Completion#complete
        # (used for ambiguity resolution) throws exceptions containing
        # the word 'ambiguous' whenever resolution fails
        explain_error(:ambiguous_completion)
      else
        explain_error(:invalid_type)
      end
      retry
    rescue Question::NoAutoCompleteMatch
      explain_error(:no_completion)
      retry
    ensure
      @question = nil    # Reset Question object.
    end
  end

  #
  # This method is HighLine's menu handler.  For simple usage, you can just
  # pass all the menu items you wish to display.  At that point, choose() will
  # build and display a menu, walk the user through selection, and return
  # their choice among the provided items.  You might use this in a case
  # statement for quick and dirty menus.
  #
  # However, choose() is capable of much more.  If provided, a block will be
  # passed a HighLine::Menu object to configure.  Using this method, you can
  # customize all the details of menu handling from index display, to building
  # a complete shell-like menuing system.  See HighLine::Menu for all the
  # methods it responds to.
  #
  # Raises EOFError if input is exhausted.
  #
  def choose( *items, &details )
    @menu = @question = Menu.new(&details)
    @menu.choices(*items) unless items.empty?

    # Set auto-completion
    @menu.completion = @menu.options
    # Set _answer_type_ so we can double as the Question for ask().
    @menu.answer_type = if @menu.shell
      lambda do |command|    # shell-style selection
        first_word = command.to_s.split.first || ""

        options = @menu.options
        options.extend(OptionParser::Completion)
        answer = options.complete(first_word)

        if answer.nil?
          raise Question::NoAutoCompleteMatch
        end

        [answer.last, command.sub(/^\s*#{first_word}\s*/, "")]
      end
    else
      @menu.options          # normal menu selection, by index or name
    end

    # Provide hooks for ERb layouts.
    @header   = @menu.header
    @prompt   = @menu.prompt

    if @menu.shell
      selected = ask("Ignored", @menu.answer_type)
      @menu.select(self, *selected)
    else
      selected = ask("Ignored", @menu.answer_type)
      @menu.select(self, selected)
    end
  end

  #
  # This method provides easy access to ANSI color sequences, without the user
  # needing to remember to CLEAR at the end of each sequence.  Just pass the
  # _string_ to color, followed by a list of _colors_ you would like it to be
  # affected by.  The _colors_ can be HighLine class constants, or symbols
  # (:blue for BLUE, for example).  A CLEAR will automatically be embedded to
  # the end of the returned String.
  #
  # This method returns the original _string_ unchanged if HighLine::use_color?
  # is +false+.
  #
  def self.color( string, *colors )
    return string unless self.use_color?
    Style(*colors).color(string)
  end

  # In case you just want the color code, without the embedding and the CLEAR
  def self.color_code(*colors)
    Style(*colors).code
  end

  # Works as an instance method, same as the class method
  def color_code(*colors)
    self.class.color_code(*colors)
  end

  # Works as an instance method, same as the class method
  def color(*args)
    self.class.color(*args)
  end

  # Remove color codes from a string
  def self.uncolor(string)
    Style.uncolor(string)
  end

  # Works as an instance method, same as the class method
  def uncolor(string)
    self.class.uncolor(string)
  end

  #
  # This method is a utility for quickly and easily laying out lists.  It can
  # be accessed within ERb replacements of any text that will be sent to the
  # user.
  #
  # The only required parameter is _items_, which should be the Array of items
  # to list.  A specified _mode_ controls how that list is formed and _option_
  # has different effects, depending on the _mode_.  Recognized modes are:
  #
  # <tt>:columns_across</tt>::         _items_ will be placed in columns,
  #                                    flowing from left to right.  If given,
  #                                    _option_ is the number of columns to be
  #                                    used.  When absent, columns will be
  #                                    determined based on _wrap_at_ or a
  #                                    default of 80 characters.
  # <tt>:columns_down</tt>::           Identical to <tt>:columns_across</tt>,
  #                                    save flow goes down.
  # <tt>:uneven_columns_across</tt>::  Like <tt>:columns_across</tt> but each
  #                                    column is sized independently.
  # <tt>:uneven_columns_down</tt>::    Like <tt>:columns_down</tt> but each
  #                                    column is sized independently.
  # <tt>:inline</tt>::                 All _items_ are placed on a single line.
  #                                    The last two _items_ are separated by
  #                                    _option_ or a default of " or ".  All
  #                                    other _items_ are separated by ", ".
  # <tt>:rows</tt>::                   The default mode.  Each of the _items_ is
  #                                    placed on its own line.  The _option_
  #                                    parameter is ignored in this mode.
  #
  # Each member of the _items_ Array is passed through ERb and thus can contain
  # their own expansions.  Color escape expansions do not contribute to the
  # final field width.
  #
  def list( items, mode = :rows, option = nil )
    items = items.to_ary.map do |item|
      if item.nil?
        ""
      else
        ERB.new(item, nil, "%").result(binding)
      end
    end

    if items.empty?
      ""
    else
      case mode
      when :inline
        option = " or " if option.nil?

        if items.size == 1
          items.first
        else
          items[0..-2].join(", ") + "#{option}#{items.last}"
        end
      when :columns_across, :columns_down
        max_length = actual_length(
          items.max { |a, b| actual_length(a) <=> actual_length(b) }
        )

        if option.nil?
          limit  = @wrap_at || 80
          option = (limit + 2) / (max_length + 2)
        end

        items = items.map do |item|
          pad = max_length + (item.to_s.length - actual_length(item))
          "%-#{pad}s" % item
        end
        row_count = (items.size / option.to_f).ceil

        if mode == :columns_across
          rows = Array.new(row_count) { Array.new }
          items.each_with_index do |item, index|
            rows[index / option] << item
          end

          rows.map { |row| row.join("  ") + "\n" }.join
        else
          columns = Array.new(option) { Array.new }
          items.each_with_index do |item, index|
            columns[index / row_count] << item
          end

          list = ""
          columns.first.size.times do |index|
            list << columns.map { |column| column[index] }.
                            compact.join("  ") + "\n"
          end
          list
        end
      when :uneven_columns_across
        if option.nil?
          limit = @wrap_at || 80
          items.size.downto(1) do |column_count|
            row_count = (items.size / column_count.to_f).ceil
            rows      = Array.new(row_count) { Array.new }
            items.each_with_index do |item, index|
              rows[index / column_count] << item
            end

            widths = Array.new(column_count, 0)
            rows.each do |row|
              row.each_with_index do |field, column|
                size           = actual_length(field)
                widths[column] = size if size > widths[column]
              end
            end

            if column_count == 1 or
               widths.inject(0) { |sum, n| sum + n + 2 } <= limit + 2
              return rows.map { |row|
                row.zip(widths).map { |field, i|
                  "%-#{i + (field.to_s.length - actual_length(field))}s" % field
                }.join("  ") + "\n"
              }.join
            end
          end
        else
          row_count = (items.size / option.to_f).ceil
          rows      = Array.new(row_count) { Array.new }
          items.each_with_index do |item, index|
            rows[index / option] << item
          end

          widths = Array.new(option, 0)
          rows.each do |row|
            row.each_with_index do |field, column|
              size           = actual_length(field)
              widths[column] = size if size > widths[column]
            end
          end

          return rows.map { |row|
            row.zip(widths).map { |field, i|
              "%-#{i + (field.to_s.length - actual_length(field))}s" % field
            }.join("  ") + "\n"
          }.join
        end
      when :uneven_columns_down
        if option.nil?
          limit = @wrap_at || 80
          items.size.downto(1) do |column_count|
            row_count = (items.size / column_count.to_f).ceil
            columns   = Array.new(column_count) { Array.new }
            items.each_with_index do |item, index|
              columns[index / row_count] << item
            end

            widths = Array.new(column_count, 0)
            columns.each_with_index do |column, i|
              column.each do |field|
                size      = actual_length(field)
                widths[i] = size if size > widths[i]
              end
            end

            if column_count == 1 or
               widths.inject(0) { |sum, n| sum + n + 2 } <= limit + 2
              list = ""
              columns.first.size.times do |index|
                list << columns.zip(widths).map { |column, width|
                  field = column[index]
                  "%-#{width + (field.to_s.length - actual_length(field))}s" %
                  field
                }.compact.join("  ").strip + "\n"
              end
              return list
            end
          end
        else
          row_count = (items.size / option.to_f).ceil
          columns   = Array.new(option) { Array.new }
          items.each_with_index do |item, index|
            columns[index / row_count] << item
          end

          widths = Array.new(option, 0)
          columns.each_with_index do |column, i|
            column.each do |field|
              size      = actual_length(field)
              widths[i] = size if size > widths[i]
            end
          end

          list = ""
          columns.first.size.times do |index|
            list << columns.zip(widths).map { |column, width|
              field = column[index]
              "%-#{width + (field.to_s.length - actual_length(field))}s" % field
            }.compact.join("  ").strip + "\n"
          end
          return list
        end
      else
        items.map { |i| "#{i}\n" }.join
      end
    end
  end

  #
  # The basic output method for HighLine objects.  If the provided _statement_
  # ends with a space or tab character, a newline will not be appended (output
  # will be flush()ed).  All other cases are passed straight to Kernel.puts().
  #
  # The _statement_ parameter is processed as an ERb template, supporting
  # embedded Ruby code.  The template is evaluated with a binding inside
  # the HighLine instance, providing easy access to the ANSI color constants
  # and the HighLine.color() method.
  #
  def say( statement )
    statement = format_statement(statement)
    return unless statement.length > 0

    out = (indentation+statement).encode(Encoding.default_external, { :undef => :replace  } )

    # Don't add a newline if statement ends with whitespace, OR
    # if statement ends with whitespace before a color escape code.
    if /[ \t](\e\[\d+(;\d+)*m)?\Z/ =~ statement
      @output.print(out)
      @output.flush
    else
      @output.puts(out)
    end
  end

  #
  # Set to an integer value to cause HighLine to wrap output lines at the
  # indicated character limit.  When +nil+, the default, no wrapping occurs.  If
  # set to <tt>:auto</tt>, HighLine will attempt to determine the columns
  # available for the <tt>@output</tt> or use a sensible default.
  #
  def wrap_at=( setting )
    @wrap_at = setting == :auto ? output_cols : setting
  end

  #
  # Set to an integer value to cause HighLine to page output lines over the
  # indicated line limit.  When +nil+, the default, no paging occurs.  If
  # set to <tt>:auto</tt>, HighLine will attempt to determine the rows available
  # for the <tt>@output</tt> or use a sensible default.
  #
  def page_at=( setting )
    @page_at = setting == :auto ? output_rows - 2 : setting
  end

  #
  # Outputs indentation with current settings
  #
  def indentation
    return ' '*@indent_size*@indent_level
  end

  #
  # Executes block or outputs statement with indentation
  #
  def indent(increase=1, statement=nil, multiline=nil)
    @indent_level += increase
    multi = @multi_indent
    @multi_indent = multiline unless multiline.nil?
    begin
        if block_given?
            yield self
        else
            say(statement)
        end
    rescue
        @multi_indent = multi
        @indent_level -= increase
        raise
    end
    @multi_indent = multi
    @indent_level -= increase
  end

  #
  # Outputs newline
  #
  def newline
    @output.puts
  end

  #
  # Returns the number of columns for the console, or a default it they cannot
  # be determined.
  #
  def output_cols
    return 80 unless @output.tty?
    terminal_size.first
  rescue
    return 80
  end

  #
  # Returns the number of rows for the console, or a default if they cannot be
  # determined.
  #
  def output_rows
    return 24 unless @output.tty?
    terminal_size.last
  rescue
    return 24
  end

  private

  def format_statement statement
    statement = String(statement || "").dup
    return statement unless statement.length > 0

    template  = ERB.new(statement, nil, "%")
    statement = template.result(binding)

    statement = wrap(statement) unless @wrap_at.nil?
    statement = page_print(statement) unless @page_at.nil?

    # 'statement' is encoded in US-ASCII when using ruby 1.9.3(-p551)
    # 'indentation' is correctly encoded (same as default_external encoding)
    statement = statement.force_encoding(Encoding.default_external)

    statement = statement.gsub(/\n(?!$)/,"\n#{indentation}") if @multi_indent

    statement
  end

  #
  # A helper method for sending the output stream and error and repeat
  # of the question.
  #
  def explain_error( error )
    say(@question.responses[error]) unless error.nil?
    if @question.responses[:ask_on_error] == :question
      say(@question)
    elsif @question.responses[:ask_on_error]
      say(@question.responses[:ask_on_error])
    end
  end

  #
  # Collects an Array/Hash full of answers as described in
  # HighLine::Question.gather().
  #
  # Raises EOFError if input is exhausted.
  #
  def gather(  )
    original_question = @question
    original_question_string = @question.question
    original_gather = @question.gather

    verify_match = @question.verify_match
    @question.gather = false

    begin   # when verify_match is set this loop will repeat until unique_answers == 1
      @answers          = [ ]
      @gather = original_gather
      original_question.question = original_question_string

      case @gather
      when Integer
        @answers << ask(@question)
        @gather  -= 1

        original_question.question = ""
        until @gather.zero?
          @question =  original_question
          @answers  << ask(@question)
          @gather   -= 1
        end
      when ::String, Regexp
        @answers << ask(@question)

        original_question.question = ""
        until (@gather.is_a?(::String) and @answers.last.to_s == @gather) or
            (@gather.is_a?(Regexp) and @answers.last.to_s =~ @gather)
          @question =  original_question
          @answers  << ask(@question)
        end

        @answers.pop
      when Hash
        @answers = { }
        @gather.keys.sort.each do |key|
          @question     = original_question
          @key          = key
          @answers[key] = ask(@question)
        end
      end

      if verify_match && (unique_answers(@answers).size > 1)
        @question =  original_question
        explain_error(:mismatch)
      else
        verify_match = false
      end

    end while verify_match

    original_question.verify_match ? @answer : @answers
  end

  #
  # A helper method used by HighLine::Question.verify_match
  # for finding whether a list of answers match or differ
  # from each other.
  #
  def unique_answers(list = @answers)
    (list.respond_to?(:values) ? list.values : list).uniq
  end

  #
  # Read a line of input from the input stream and process whitespace as
  # requested by the Question object.
  #
  # If Question's _readline_ property is set, that library will be used to
  # fetch input.  *WARNING*:  This ignores the currently set input stream.
  #
  # Raises EOFError if input is exhausted.
  #
  def get_line(  )
    if @question.readline
      require "readline"    # load only if needed

      # capture say()'s work in a String to feed to readline()
      old_output = @output
      @output    = StringIO.new
      say(@question)
      question = @output.string
      @output  = old_output

      # prep auto-completion
      Readline.completion_proc = lambda do |string|
        @question.selection.grep(/\A#{Regexp.escape(string)}/)
      end

      # work-around ugly readline() warnings
      old_verbose = $VERBOSE
      $VERBOSE    = nil
      raw_answer  = Readline.readline(question, true)
      if raw_answer.nil?
        if @@track_eof
          raise EOFError, "The input stream is exhausted."
        else
          raw_answer = String.new # Never return nil
        end
      end
      answer      = @question.change_case(
                        @question.remove_whitespace(raw_answer))
      $VERBOSE    = old_verbose

      answer
    else
      if JRUBY
        statement = format_statement(@question)
        raw_answer = @java_console.readLine(statement, nil)

        raise EOFError, "The input stream is exhausted." if raw_answer.nil? and
                                                            @@track_eof
      else
        raise EOFError, "The input stream is exhausted." if @@track_eof and
                                                            @input.eof?
        raw_answer = @input.gets
      end

      @question.change_case(@question.remove_whitespace(raw_answer))
    end
  end

  #
  # Return a line or character of input, as requested for this question.
  # Character input will be returned as a single character String,
  # not an Integer.
  #
  # This question's _first_answer_ will be returned instead of input, if set.
  #
  # Raises EOFError if input is exhausted.
  #
  def get_response(  )
    return @question.first_answer if @question.first_answer?

    if @question.character.nil?
      if @question.echo == true and @question.limit.nil?
        get_line
      else
        raw_no_echo_mode

        line            = "".encode(Encoding::BINARY)
        backspace_limit = 0
        begin

          while character = get_character(@input)
            # honor backspace and delete
            if character == 127 or character == 8
              line = line.force_encoding(Encoding.default_external)
              line.slice!(-1, 1)
              backspace_limit -= 1
              line = line.force_encoding(Encoding::BINARY)
            else
              line << character.chr
              backspace_limit = line.dup.force_encoding(Encoding.default_external).size
            end
            # looking for carriage return (decimal 13) or
            # newline (decimal 10) in raw input
            break if character == 13 or character == 10
            if @question.echo != false
              if character == 127 or character == 8
                # only backspace if we have characters on the line to
                # eliminate, otherwise we'll tromp over the prompt
                if backspace_limit >= 0 then
                  @output.print("\b#{HighLine.Style(:erase_char).code}")
                else
                    # do nothing
                end
              else
                line_with_next_char_encoded = line.dup.force_encoding(Encoding.default_external)
                # For multi-byte character, does this
                #   last character completes the character?
                # Then print it.
                if line_with_next_char_encoded.valid_encoding?
                  if @question.echo == true
                    @output.print(line_with_next_char_encoded[-1])
                  else
                    @output.print(@question.echo)
                  end
                end
              end
              @output.flush
            end
            break if @question.limit and line.size == @question.limit
          end
        ensure
          restore_mode
        end
        if @question.overwrite
          @output.print("\r#{HighLine.Style(:erase_line).code}")
          @output.flush
        else
          say("\n")
        end

        @question.change_case(@question.remove_whitespace(line.force_encoding(Encoding.default_external)))
      end
    else
      if JRUBY #prompt has not been shown
        say @question
      end

      raw_no_echo_mode
      begin
        if @question.character == :getc
          response = @input.getbyte.chr
        else
          response = get_character(@input).chr
          if @question.overwrite
            @output.print("\r#{HighLine.Style(:erase_line).code}")
            @output.flush
          else
            echo = if @question.echo == true
              response
            elsif @question.echo != false
              @question.echo
            else
              ""
            end
            say("#{echo}\n")
          end
        end
      ensure
        restore_mode
      end
      @question.change_case(response)
    end
  end

  #
  # Page print a series of at most _page_at_ lines for _output_.  After each
  # page is printed, HighLine will pause until the user presses enter/return
  # then display the next page of data.
  #
  # Note that the final page of _output_ is *not* printed, but returned
  # instead.  This is to support any special handling for the final sequence.
  #
  def page_print( output )
    lines = output.lines.to_a
    while lines.size > @page_at
      @output.puts lines.slice!(0...@page_at).join
      @output.puts
      # Return last line if user wants to abort paging
      return "...\n#{lines.last}" unless continue_paging?
    end
    return lines.join
  end

  #
  # Ask user if they wish to continue paging output. Allows them to type "q" to
  # cancel the paging process.
  #
  def continue_paging?
    command = HighLine.new(@input, @output).ask(
      "-- press enter/return to continue or q to stop -- "
    ) { |q| q.character = true }
    command !~ /\A[qQ]\Z/  # Only continue paging if Q was not hit.
  end

  #
  # Wrap a sequence of _lines_ at _wrap_at_ characters per line.  Existing
  # newlines will not be affected by this process, but additional newlines
  # may be added.
  #
  def wrap( text )
    wrapped = [ ]
    text.each_line do |line|
      # take into account color escape sequences when wrapping
      wrap_at = @wrap_at + (line.length - actual_length(line))
      while line =~ /([^\n]{#{wrap_at + 1},})/
        search  = $1.dup
        replace = $1.dup
        if index = replace.rindex(" ", wrap_at)
          replace[index, 1] = "\n"
          replace.sub!(/\n[ \t]+/, "\n")
          line.sub!(search, replace)
        else
          line[$~.begin(1) + wrap_at, 0] = "\n"
        end
      end
      wrapped << line
    end
    return wrapped.join
  end

  #
  # Returns the length of the passed +string_with_escapes+, minus and color
  # sequence escapes.
  #
  def actual_length( string_with_escapes )
    string_with_escapes.to_s.gsub(/\e\[\d{1,2}m/, "").length
  end
end

require "highline/string_extensions"
