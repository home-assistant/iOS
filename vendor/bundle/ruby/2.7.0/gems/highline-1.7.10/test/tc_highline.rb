# encoding: utf-8
# tc_highline.rb
#
#  Created by James Edward Gray II on 2005-04-26.
#  Copyright 2005 Gray Productions. All rights reserved.
#
#  This is Free Software.  See LICENSE and COPYING for details.

require "test/unit"

require "highline"
require "stringio"
require "readline"
require "tempfile"

if HighLine::CHARACTER_MODE == "Win32API"
  class HighLine
    # Override Windows' character reading so it's not tied to STDIN.
    def get_character( input = STDIN )
      input.getc
    end
  end
end

class TestHighLine < Test::Unit::TestCase
  def setup
    @input    = StringIO.new
    @output   = StringIO.new
    @terminal = HighLine.new(@input, @output)  
  end
  
  def test_agree
    @input << "y\nyes\nYES\nHell no!\nNo\n"
    @input.rewind

    assert_equal(true, @terminal.agree("Yes or no?  "))
    assert_equal(true, @terminal.agree("Yes or no?  "))
    assert_equal(true, @terminal.agree("Yes or no?  "))
    assert_equal(false, @terminal.agree("Yes or no?  "))
    
    @input.truncate(@input.rewind)
    @input << "yellow"
    @input.rewind

    assert_equal(true, @terminal.agree("Yes or no?  ", :getc))
  end
  
  def test_agree_with_block
    @input << "\n\n"
    @input.rewind

    assert_equal(true, @terminal.agree("Yes or no?  ") { |q| q.default = "y" })
    assert_equal(false, @terminal.agree("Yes or no?  ") { |q| q.default = "n" })
  end
  
  def test_ask
    name = "James Edward Gray II"
    @input << name << "\n"
    @input.rewind

    assert_equal(name, @terminal.ask("What is your name?  "))
    
    assert_raise(EOFError) { @terminal.ask("Any input left?  ") }
  end
  
  def test_ask_string
    name = "James Edward Gray II"
    @input << name << "\n"
    @input.rewind

    assert_equal(name, @terminal.ask("What is your name?  ", String))

    assert_raise(EOFError) { @terminal.ask("Any input left?  ", String) }
  end

  def test_indent
    text = "Testing...\n"
    @terminal.indent_level=1
    @terminal.say(text)
    assert_equal(' '*3+text, @output.string)

    @output.truncate(@output.rewind)
    @terminal.indent_level=3
    @terminal.say(text)
    assert_equal(' '*9+text, @output.string)

    @output.truncate(@output.rewind)
    @terminal.indent_level=0
    @terminal.indent_size=5
    @terminal.indent(2, text)
    assert_equal(' '*10+text, @output.string)

    @output.truncate(@output.rewind)
    @terminal.indent_size=4
    @terminal.indent {
        @terminal.say(text)
    }
    assert_equal(' '*4+text, @output.string)

    @output.truncate(@output.rewind)
    @terminal.indent_size=2
    @terminal.indent(3) { |t|
        t.say(text)
    }
    assert_equal(' '*6+text, @output.string)

    @output.truncate(@output.rewind)
    @terminal.indent { |t|
        t.indent {
            t.indent {
                t.indent { |tt|
                    tt.say(text)
                }
            }
        }
    }
    assert_equal(' '*8+text, @output.string)

    text = "Multi\nLine\nIndentation\n"
    indent = ' '*4
    @terminal.indent_level=2
    @output.truncate(@output.rewind)
    @terminal.say(text)
    assert_equal("#{indent}Multi\n#{indent}Line\n#{indent}Indentation\n", @output.string)

    @output.truncate(@output.rewind)
    @terminal.multi_indent = false
    @terminal.say(text)
    assert_equal("#{indent}Multi\nLine\nIndentation\n", @output.string)

    @output.truncate(@output.rewind)
    @terminal.indent(0, text, true)
    assert_equal("#{indent}Multi\n#{indent}Line\n#{indent}Indentation\n", @output.string)
  end
  
  def test_newline
    @terminal.newline
    @terminal.newline
    assert_equal("\n\n", @output.string)
  end

  def test_bug_fixes
    # auto-complete bug
    @input << "ruby\nRuby\n"
    @input.rewind

    languages = [:Perl, :Python, :Ruby]
    answer = @terminal.ask( "What is your favorite programming language?  ",
                            languages )
    assert_equal(languages.last, answer)

    @input.truncate(@input.rewind)
    @input << "ruby\n"
    @input.rewind

    answer = @terminal.ask( "What is your favorite programming language?  ",
                            languages ) do |q|
      q.case = :capitalize
    end
    assert_equal(languages.last, answer)
    
    # poor auto-complete error message
    @input.truncate(@input.rewind)
    @input << "lisp\nruby\n"
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask( "What is your favorite programming language?  ",
                            languages ) do |q|
      q.case = :capitalize
    end
    assert_equal(languages.last, answer)
    assert_equal( "What is your favorite programming language?  " +
                  "You must choose one of [Perl, Python, Ruby].\n" +
                  "?  ", @output.string )
  end
  
  def test_case_changes
    @input << "jeg2\n"
    @input.rewind

    answer = @terminal.ask("Enter your initials  ") do |q|
      q.case = :up
    end
    assert_equal("JEG2", answer)

    @input.truncate(@input.rewind)
    @input << "cRaZY\n"
    @input.rewind

    answer = @terminal.ask("Enter a search string:  ") do |q|
      q.case = :down
    end
    assert_equal("crazy", answer)
  end

  def test_character_echo
    @input << "password\r"
    @input.rewind

    answer = @terminal.ask("Please enter your password:  ") do |q|
      q.echo = "*"
    end
    assert_equal("password", answer)
    assert_equal("Please enter your password:  ********\n", @output.string)

    @input.truncate(@input.rewind)
    @input << "2"
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask( "Select an option (1, 2 or 3):  ",
                            Integer ) do |q|
      q.echo      = "*"
      q.character = true
    end
    assert_equal(2, answer)
    assert_equal("Select an option (1, 2 or 3):  *\n", @output.string)
  end

  def test_backspace_does_not_enter_prompt
      @input << "\b\b"
      @input.rewind
      answer = @terminal.ask("Please enter your password: ") do |q| 
        q.echo = "*" 
      end
      assert_equal("", answer)
      assert_equal("Please enter your password: \n", @output.string)
  end

  def test_after_some_chars_backspace_does_not_enter_prompt_when_ascii
      @input << "apple\b\b\b\b\b\b\b\b\b\b"
      @input.rewind
      answer = @terminal.ask("Please enter your password: ") do |q|
        q.echo = "*"
      end
      assert_equal("", answer)
      assert_equal("apple".size, @output.string.count("\b"))
  end

  def test_after_some_chars_backspace_does_not_enter_prompt_when_utf8
      @input << "maçã\b\b\b\b\b\b\b\b"
      @input.rewind
      answer = @terminal.ask("Please enter your password: ") do |q|
        q.echo = "*"
      end
      assert_equal("", answer)
      assert_equal("maçã".size, @output.string.count("\b"))
  end

  def test_readline_mode
    # Rubinius seems to be ignoring Readline input
    # and output assignments. This ruins testing.
    # but it doesn't mean readline is not working
    # properly on rubinius.

    return if RUBY_ENGINE == "rbx"

    # Creating Tempfiles here because Readline.input
    #   and Readline.output only accepts a File object
    #   as argument (not any duck type as StringIO)

    temp_stdin  = Tempfile.new "temp_stdin"
    temp_stdout = Tempfile.new "temp_stdout"

    Readline.input  = @input  = File.open(temp_stdin.path, 'w+')
    Readline.output = @output = File.open(temp_stdout.path, 'w+')

    @terminal = HighLine.new(@input, @output)

    @input << "any input\n"
    @input.rewind

    answer = @terminal.ask("Prompt:  ") do |q|
      q.readline = true
    end

    @output.rewind
    output = @output.read

    assert_equal "any input", answer
    assert_match "Prompt:  any input\n", output

    @input.close
    @output.close
    Readline.input  = STDIN
    Readline.output = STDOUT
  end

  def test_readline_mode_with_limit_set
    temp_stdin  = Tempfile.new "temp_stdin"
    temp_stdout = Tempfile.new "temp_stdout"

    Readline.input  = @input  = File.open(temp_stdin.path, 'w+')
    Readline.output = @output = File.open(temp_stdout.path, 'w+')

    @terminal = HighLine.new(@input, @output)

    @input << "any input\n"
    @input.rewind

    answer = @terminal.ask("Prompt:  ") do |q|
      q.limit = 50
      q.readline = true
    end

    @output.rewind
    output = @output.read

    assert_equal "any input", answer
    assert_equal "Prompt:  any input\n", output

    @input.close
    @output.close
    Readline.input  = STDIN
    Readline.output = STDOUT
  end

  def test_readline_on_non_echo_question_has_prompt
    @input << "you can't see me"
    @input.rewind
    answer = @terminal.ask("Please enter some hidden text: ") do |q|
      q.readline = true
      q.echo = "*"
    end
    assert_equal("you can't see me", answer)
    assert_equal("Please enter some hidden text: ****************\n", @output.string)
  end
  
  def test_character_reading
    # WARNING:  This method does NOT cover Unix and Windows savvy testing!
    @input << "12345"
    @input.rewind

    answer = @terminal.ask("Enter a single digit:  ", Integer) do |q|
      q.character = :getc
    end
    assert_equal(1, answer)
  end

  def test_frozen_statement
    @terminal.say('This is a frozen statement'.freeze)
    assert_equal("This is a frozen statement\n", @output.string)
  end

  def test_color
    @terminal.say("This should be <%= BLUE %>blue<%= CLEAR %>!")
    assert_equal("This should be \e[34mblue\e[0m!\n", @output.string)

    @output.truncate(@output.rewind)

    @terminal.say( "This should be " +
                   "<%= BOLD + ON_WHITE %>bold on white<%= CLEAR %>!" )
    assert_equal( "This should be \e[1m\e[47mbold on white\e[0m!\n",
                  @output.string )

    @output.truncate(@output.rewind)

    @terminal.say("This should be <%= color('cyan', CYAN) %>!")
    assert_equal("This should be \e[36mcyan\e[0m!\n", @output.string)

    @output.truncate(@output.rewind)

    @terminal.say( "This should be " +
                   "<%= color('blinking on red', :blink, :on_red) %>!" )
    assert_equal( "This should be \e[5m\e[41mblinking on red\e[0m!\n",
                  @output.string )

    @output.truncate(@output.rewind)

    @terminal.say("This should be <%= NONE %>none<%= CLEAR %>!")
    assert_equal("This should be \e[38mnone\e[0m!\n", @output.string)

    @output.truncate(@output.rewind)

    @terminal.say("This should be <%= RGB_906030 %>rgb_906030<%= CLEAR %>!")
    assert_equal("This should be \e[38;5;137mrgb_906030\e[0m!\n", @output.string)

    @output.truncate(@output.rewind)

    @terminal.say("This should be <%= ON_RGB_C06030 %>on_rgb_c06030<%= CLEAR %>!")
    assert_equal("This should be \e[48;5;173mon_rgb_c06030\e[0m!\n", @output.string)

    @output.truncate(@output.rewind)
    
    # Does class method work, too?
    @terminal.say("This should be <%= HighLine.color('reverse underlined magenta', :reverse, :underline, :magenta) %>!")
    assert_equal( "This should be \e[7m\e[4m\e[35mreverse underlined magenta\e[0m!\n",
                  @output.string )

    @output.truncate(@output.rewind)

    # turn off color
    old_setting = HighLine.use_color?
    assert_nothing_raised(Exception) { HighLine.use_color = false }
    @terminal.say("This should be <%= color('cyan', CYAN) %>!")
    assert_equal("This should be cyan!\n", @output.string)
    HighLine.use_color = old_setting
  end

  def test_uncolor
    # instance method
    assert_equal( "This should be reverse underlined magenta!\n",
                  @terminal.uncolor("This should be \e[7m\e[4m\e[35mreverse underlined magenta\e[0m!\n") 
                )

    @output.truncate(@output.rewind)

    # class method
    assert_equal( "This should be reverse underlined magenta!\n",
                  HighLine.uncolor("This should be \e[7m\e[4m\e[35mreverse underlined magenta\e[0m!\n") 
                )

    @output.truncate(@output.rewind)

    # RGB color
    assert_equal( "This should be rgb_906030!\n",
                  @terminal.uncolor("This should be \e[38;5;137mrgb_906030\e[0m!\n") 
                )
  end

  def test_grey_is_the_same_of_gray
    @terminal.say("<%= GRAY %>")
    gray_code = @output.string.dup
    @output.truncate(@output.rewind)

    @terminal.say("<%= GREY %>")
    grey_code = @output.string.dup
    @output.truncate(@output.rewind)

    assert_equal gray_code, grey_code
  end

  def test_light_is_the_same_as_bright
    @terminal.say("<%= BRIGHT_BLUE %>")
    bright_blue_code = @output.string.dup
    @output.truncate(@output.rewind)

    @terminal.say("<%= LIGHT_BLUE %>")
    light_blue_code = @output.string.dup
    @output.truncate(@output.rewind)

    assert_equal bright_blue_code, light_blue_code
  end
                                  
  def test_confirm
    @input << "junk.txt\nno\nsave.txt\ny\n"
    @input.rewind

    answer = @terminal.ask("Enter a filename:  ") do |q|
      q.confirm = "Are you sure you want to overwrite <%= @answer %>?  "
      q.responses[:ask_on_error] = :question
    end
    assert_equal("save.txt", answer)
    assert_equal( "Enter a filename:  " +
                  "Are you sure you want to overwrite junk.txt?  " +
                  "Enter a filename:  " +
                  "Are you sure you want to overwrite save.txt?  ",
                  @output.string )

    @input.truncate(@input.rewind)
    @input << "junk.txt\nyes\nsave.txt\nn\n"
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask("Enter a filename:  ") do |q|
      q.confirm = "Are you sure you want to overwrite <%= @answer %>?  "
    end
    assert_equal("junk.txt", answer)
    assert_equal( "Enter a filename:  " +
                  "Are you sure you want to overwrite junk.txt?  ",
                  @output.string )
  end
  
  def test_defaults
    @input << "\nNo Comment\n"
    @input.rewind

    answer = @terminal.ask("Are you sexually active?  ") do |q|
      q.validate = /\Ay(?:es)?|no?|no comment\Z/i
    end
    assert_equal("No Comment", answer)

    @input.truncate(@input.rewind)
    @input << "\nYes\n"
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask("Are you sexually active?  ") do |q|
      q.default  = "No Comment"
      q.validate = /\Ay(?:es)?|no?|no comment\Z/i
    end
    assert_equal("No Comment", answer)
    assert_equal( "Are you sexually active?  |No Comment|  ",
                  @output.string )
  end

  def test_default_with_String
    @input << "\n"
    @input.rewind

    answer = @terminal.ask("Question:  ") do |q|
      q.default = "string"
    end

    assert_equal "string", answer
    assert_equal "Question:  |string|  ", @output.string
  end

  def test_default_with_Symbol
    # With a Symbol, it should show up the String version
    #   at prompt, but return the Symbol as answer

    @input << "\n"
    @input.rewind

    answer = @terminal.ask("Question:  ") do |q|
      q.default = :string
    end

    assert_equal :string, answer
    assert_equal "Question:  |string|  ", @output.string
  end

  def test_default_with_non_String_objects
    # With a non-string object, it should not show
    #   any 'default' at prompt line. And should
    #   return the "default" object, without conversion.

    @input << "\n"
    @input.rewind

    default_non_string_object = Object.new

    answer = @terminal.ask("Question:  ") do |q|
      q.default = default_non_string_object
    end

    assert_equal default_non_string_object, answer
    assert_equal "Question:  ", @output.string
  end

  def test_string_preservation
    @input << "Maybe\nYes\n"
    @input.rewind

    my_string = "Is that your final answer? "

    @terminal.ask(my_string) { |q| q.default = "Possibly" }
    @terminal.ask(my_string) { |q| q.default = "Maybe" }

    assert_equal("Is that your final answer? ", my_string)
  end

  def test_empty
    @input << "\n"
    @input.rewind

    answer = @terminal.ask("") do |q|
      q.default  = "yes"
      q.validate = /\Ay(?:es)?|no?\Z/i
    end
    assert_equal("yes", answer)
  end
  
  def test_erb
    @terminal.say( "The integers from 1 to 10 are:\n" +
                   "% (1...10).each do |n|\n" +
                   "\t<%= n %>,\n" +
                   "% end\n" +
                   "\tand 10" )
    assert_equal( "The integers from 1 to 10 are:\n" +
                  "\t1,\n\t2,\n\t3,\n\t4,\n\t5,\n" +
                  "\t6,\n\t7,\n\t8,\n\t9,\n\tand 10\n",
                  @output.string )
  end
  
  def test_files
    @input << "#{File.basename(__FILE__)[0, 5]}\n"
    @input.rewind
    
    assert_equal "tc_hi\n",@input.read
    @input.rewind

    file = @terminal.ask("Select a file:  ", File) do |q|
      q.directory = File.expand_path(File.dirname(__FILE__))
      q.glob      = "*.rb"
    end
    assert_instance_of(File, file)
    assert_equal("# encoding: utf-8\n", file.gets)
    file.close

    @input.rewind

    pathname = @terminal.ask("Select a file:  ", Pathname) do |q|
      q.directory = File.expand_path(File.dirname(__FILE__))
      q.glob      = "*.rb"
    end
    assert_instance_of(Pathname, pathname)
    assert_equal(File.size(__FILE__), pathname.size)
  end
  
  def test_gather
    @input << "James\nDana\nStorm\nGypsy\n\n"
    @input.rewind

    answers = @terminal.ask("Enter four names:") do |q|
      q.gather = 4
    end
    assert_equal(%w{James Dana Storm Gypsy}, answers)
    assert_equal("\n", @input.gets)
    assert_equal("Enter four names:\n", @output.string)

    @input.rewind

    answers = @terminal.ask("Enter four names:") do |q|
      q.gather = ""
    end
    assert_equal(%w{James Dana Storm Gypsy}, answers)

    @input.rewind

    answers = @terminal.ask("Enter four names:") do |q|
      q.gather = /^\s*$/
    end
    assert_equal(%w{James Dana Storm Gypsy}, answers)

    @input.truncate(@input.rewind)
    @input << "29\n49\n30\n"
    @input.rewind
    @output.truncate(@output.rewind)

    answers = @terminal.ask("<%= @key %>:  ", Integer) do |q|
      q.gather = { "Age" => 0, "Wife's Age" => 0, "Father's Age" => 0}
    end
    assert_equal( { "Age" => 29, "Wife's Age" => 30, "Father's Age" => 49},
                  answers )
    assert_equal("Age:  Father's Age:  Wife's Age:  ", @output.string)
  end

  def test_typing_verification
    @input << "all work and no play makes jack a dull boy\n" * 3
    @input.rewind

    answer = @terminal.ask("How's work? ") do |q|
      q.gather = 3
      q.verify_match = true
    end
    assert_equal("all work and no play makes jack a dull boy", answer)

    @input.truncate(@input.rewind)
    @input << "all play and no work makes jack a mere toy\n"
    @input << "all work and no play makes jack a dull boy\n" * 5
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask("How are things going? ") do |q|
      q.gather = 3
      q.verify_match = true
      q.responses[:mismatch] = 'Typing mismatch!'
      q.responses[:ask_on_error] = ''
    end
    assert_equal("all work and no play makes jack a dull boy", answer)

    # now try using a hash for gather

    @input.truncate(@input.rewind)
    @input << "Password\nPassword\n"
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask("<%= @key %>: ") do |q|
      q.verify_match = true
      q.gather = {"Enter a password" => '', "Please type it again" => ''}
    end
    assert_equal("Password", answer)

    @input.truncate(@input.rewind)
    @input << "Password\nMistake\nPassword\nPassword\n"
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask("<%= @key %>: ") do |q|
      q.verify_match = true
      q.responses[:mismatch] = 'Typing mismatch!'
      q.responses[:ask_on_error] = ''
      q.gather = {"Enter a password" => '', "Please type it again" => ''}
    end

    assert_equal("Password", answer)
    assert_equal( "Enter a password: " +
                  "Please type it again: " +
                  "Typing mismatch!\n" +
                  "Enter a password: " +
                  "Please type it again: ", @output.string )
  end

  def test_lists
    digits     = %w{Zero One Two Three Four Five Six Seven Eight Nine}
    erb_digits = digits.dup
    erb_digits[erb_digits.index("Five")] = "<%= color('Five', :blue) %%>"

    @terminal.say("<%= list(#{digits.inspect}) %>")
    assert_equal(digits.map { |d| "#{d}\n" }.join, @output.string)

    @output.truncate(@output.rewind)

    @terminal.say("<%= list(#{digits.inspect}, :inline) %>")
    assert_equal( digits[0..-2].join(", ") + " or #{digits.last}\n",
                  @output.string )

    @output.truncate(@output.rewind)

    @terminal.say("<%= list(#{digits.inspect}, :inline, ' and ') %>")
    assert_equal( digits[0..-2].join(", ") + " and #{digits.last}\n",
                  @output.string )

    @output.truncate(@output.rewind)

    @terminal.say("<%= list(#{digits.inspect}, :columns_down, 3) %>")
    assert_equal( "Zero   Four   Eight\n" +
                  "One    Five   Nine \n" +
                  "Two    Six  \n"        +
                  "Three  Seven\n",
                  @output.string )

    @output.truncate(@output.rewind)

    @terminal.say("<%= list(#{erb_digits.inspect}, :columns_down, 3) %>")
    assert_equal( "Zero   Four   Eight\n" +
                  "One    \e[34mFive\e[0m   Nine \n" +
                  "Two    Six  \n" +
                  "Three  Seven\n",
                  @output.string )

    colums_of_twenty = ["12345678901234567890"] * 5
    
    @output.truncate(@output.rewind)

    @terminal.say("<%= list(#{colums_of_twenty.inspect}, :columns_down) %>")
    assert_equal( "12345678901234567890  12345678901234567890  " +
                  "12345678901234567890\n"                       +
                  "12345678901234567890  12345678901234567890\n",
                  @output.string )

    @output.truncate(@output.rewind)

    @terminal.say("<%= list(#{digits.inspect}, :columns_across, 3) %>")
    assert_equal( "Zero   One    Two  \n" +
                  "Three  Four   Five \n" + 
                  "Six    Seven  Eight\n" +
                  "Nine \n",
                  @output.string )
        
    colums_of_twenty.pop

    @output.truncate(@output.rewind)

    @terminal.say("<%= list( #{colums_of_twenty.inspect}, :columns_across ) %>")
    assert_equal( "12345678901234567890  12345678901234567890  " +
                  "12345678901234567890\n" +
                  "12345678901234567890\n",
                  @output.string )

    @output.truncate(@output.rewind)
    
    wide = %w[0123456789 a b c d e f g h i j k l m n o p q r s t u v w x y z]

    @terminal.say("<%= list( #{wide.inspect}, :uneven_columns_across ) %>")
    assert_equal( "0123456789  a  b  c  d  e  f  g  h  i  j  k  l  m  n  o  " +
                  "p  q  r  s  t  u  v  w\n"                                  +
                  "x           y  z\n",
                  @output.string )

    @output.truncate(@output.rewind)

    @terminal.say("<%= list( #{wide.inspect}, :uneven_columns_across, 10 ) %>")
    assert_equal( "0123456789  a  b  c  d  e  f  g  h  i\n" +
                  "j           k  l  m  n  o  p  q  r  s\n" +
                  "t           u  v  w  x  y  z\n",
                  @output.string )

    @output.truncate(@output.rewind)

    @terminal.say("<%= list( #{wide.inspect}, :uneven_columns_down ) %>")
    assert_equal( "0123456789  b  d  f  h  j  l  n  p  r  t  v  x  z\n" +
                  "a           c  e  g  i  k  m  o  q  s  u  w  y\n",
                  @output.string )

    @output.truncate(@output.rewind)

    @terminal.say("<%= list( #{wide.inspect}, :uneven_columns_down, 10 ) %>")
    assert_equal( "0123456789  c  f  i  l  o  r  u  x\n" +
                  "a           d  g  j  m  p  s  v  y\n" +
                  "b           e  h  k  n  q  t  w  z\n",
                  @output.string )
  end
  
  def test_lists_with_zero_items
    modes = [nil, :rows, :inline, :columns_across, :columns_down]
    modes.each do |mode|
      result = @terminal.list([], mode)
      assert_equal("", result)
    end
  end

  def test_lists_with_nil_items
    modes = [nil]
    modes.each do |mode|
      result = @terminal.list([nil], mode)
      assert_equal("\n", result)
    end
  end
  
  def test_lists_with_one_item
    items = ['Zero']
    modes = { nil            => "Zero\n",
             :rows           => "Zero\n",
             :inline         => "Zero",
             :columns_across => "Zero\n",
             :columns_down   => "Zero\n" }
             
    modes.each do |mode, expected|
      result = @terminal.list(items, mode)
      assert_equal(expected, result)
    end
  end
  
  def test_lists_with_two_items
    items = ['Zero', 'One']
    modes = { nil            => "Zero\nOne\n",
             :rows           => "Zero\nOne\n",
             :inline         => "Zero or One",
             :columns_across => "Zero  One \n",
             :columns_down   => "Zero  One \n" }
             
    modes.each do |mode, expected|
      result = @terminal.list(items, mode)
      assert_equal(expected, result)
    end
  end
  
  def test_lists_with_three_items
    items = ['Zero', 'One', 'Two']
    modes = { nil            => "Zero\nOne\nTwo\n",
             :rows           => "Zero\nOne\nTwo\n",
             :inline         => "Zero, One or Two",
             :columns_across => "Zero  One   Two \n",
             :columns_down   => "Zero  One   Two \n" }

    modes.each do |mode, expected|
      result = @terminal.list(items, mode)
      assert_equal(expected, result)
    end
  end
  
  def test_mode
    assert(%w[Win32API termios ncurses stty jline].include?(HighLine::CHARACTER_MODE),
           "#{HighLine::CHARACTER_MODE} not in list")
  end
  
  class NameClass
    def self.parse( string )
      if string =~ /^\s*(\w+),\s*(\w+)\s+(\w+)\s*$/
        self.new($2, $3, $1)
      else
        raise ArgumentError, "Invalid name format."
      end
    end

    def initialize(first, middle, last)
      @first, @middle, @last = first, middle, last
    end
    
    attr_reader :first, :middle, :last
  end
  
  def test_my_class_conversion
    @input << "Gray, James Edward\n"
    @input.rewind

    answer = @terminal.ask("Your name?  ", NameClass) do |q|
      q.validate = lambda do |name|
        names = name.split(/,\s*/)
        return false unless names.size == 2
        return false if names.first =~ /\s/
        names.last.split.size == 2
      end
    end
    assert_instance_of(NameClass, answer)
    assert_equal("Gray", answer.last)
    assert_equal("James", answer.first)
    assert_equal("Edward", answer.middle)
  end
  
  def test_no_echo
    @input << "password\r"
    @input.rewind

    answer = @terminal.ask("Please enter your password:  ") do |q|
      q.echo = false
    end
    assert_equal("password", answer)
    assert_equal("Please enter your password:  \n", @output.string)

    @input.rewind
    @output.truncate(@output.rewind)
    
    answer = @terminal.ask("Pick a letter or number:  ") do |q|
      q.character = true
      q.echo      = false
    end
    assert_equal("p", answer)
    assert_equal("a", @input.getc.chr)
    assert_equal("Pick a letter or number:  \n", @output.string)
  end
  
  def test_correct_string_encoding_when_echo_false
    @input << "ação\r" # An UTF-8 portuguese word for 'action'
    @input.rewind

    answer = @terminal.ask("Please enter your password:  ") do |q|
      q.echo = false
    end

    assert_equal "ação", answer
    assert_equal Encoding::default_external, answer.encoding
  end

  def test_backspace_with_ascii_when_echo_false
    @input << "password\b\r"
    @input.rewind

    answer = @terminal.ask("Please enter your password:  ") do |q|
      q.echo = false
    end

    assert_not_equal("password", answer)
    assert_equal("passwor", answer)
  end

  def test_backspace_with_utf8_when_echo_false
    @input << "maçã\b\r"
    @input.rewind

    answer = @terminal.ask("Please enter your password:  ") do |q|
      q.echo = false
    end

    assert_not_equal("maçã", answer)
    assert_equal("maç", answer)
  end

  def test_echoing_with_utf8_when_echo_is_star
    @input << "maçã\r"
    @input.rewind

    answer = @terminal.ask("Type:  ") do |q|
      q.echo = "*"
    end

    assert_equal("Type:  ****\n", @output.string)
    assert_equal("maçã", answer)
  end

  def test_paging
    @terminal.page_at = 22

    @input << "\n\n"
    @input.rewind

    @terminal.say((1..50).map { |n| "This is line #{n}.\n"}.join)
    assert_equal( (1..22).map { |n| "This is line #{n}.\n"}.join +
                  "\n-- press enter/return to continue or q to stop -- \n\n" +
                  (23..44).map { |n| "This is line #{n}.\n"}.join +
                  "\n-- press enter/return to continue or q to stop -- \n\n" +
                  (45..50).map { |n| "This is line #{n}.\n"}.join,
                  @output.string )
  end

  def test_statement_lines_count_equal_to_page_at_shouldnt_paginate
    @terminal.page_at = 6

    @input << "\n"
    @input.rewind

    list = "a\nb\nc\nd\ne\nf\n"

    @terminal.say(list)
    assert_equal(list, @output.string)
  end

  def test_statement_with_one_line_bigger_than_page_at_should_paginate
    @terminal.page_at = 6

    @input << "\n"
    @input.rewind

    list = "a\nb\nc\nd\ne\nf\ng\n"

    paginated =
      "a\nb\nc\nd\ne\nf\n" \
      "\n-- press enter/return to continue or q to stop -- \n\n" \
      "g\n"

    @terminal.say(list)
    assert_equal(paginated, @output.string)
  end

  def test_quiting_paging_shouldnt_raise
    # See https://github.com/JEG2/highline/issues/168

    @terminal.page_at = 6

    @input << "q"
    @input.rewind

    list = "a\nb\nc\nd\ne\nf\n"

    assert_nothing_raised { @terminal.say(list) }
  end
  
  def test_range_requirements
    @input << "112\n-541\n28\n"
    @input.rewind

    answer = @terminal.ask("Tell me your age.", Integer) do |q|
      q.in = 0..105
    end
    assert_equal(28, answer)
    assert_equal( "Tell me your age.\n" +
                  "Your answer isn't within the expected range " +
                  "(included in 0..105).\n" +
                  "?  " +
                  "Your answer isn't within the expected range " +
                  "(included in 0..105).\n" +
                  "?  ", @output.string )

    @input.truncate(@input.rewind)
    @input << "1\n-541\n28\n"
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask("Tell me your age.", Integer) do |q|
      q.above = 3
    end
    assert_equal(28, answer)
    assert_equal( "Tell me your age.\n" +
                  "Your answer isn't within the expected range " +
                  "(above 3).\n" +
                  "?  " +
                  "Your answer isn't within the expected range " +
                  "(above 3).\n" +
                  "?  ", @output.string )

    @input.truncate(@input.rewind)
    @input << "1\n28\n-541\n"
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask("Lowest numer you can think of?", Integer) do |q|
      q.below = 0
    end
    assert_equal(-541, answer)
    assert_equal( "Lowest numer you can think of?\n" +
                  "Your answer isn't within the expected range " +
                  "(below 0).\n" +
                  "?  " +
                  "Your answer isn't within the expected range " +
                  "(below 0).\n" +
                  "?  ", @output.string )

    @input.truncate(@input.rewind)
    @input << "1\n-541\n6\n"
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask("Enter a low even number:  ", Integer) do |q|
      q.above = 0
      q.below = 10
      q.in    = [2, 4, 6, 8]
    end
    assert_equal(6, answer)
    assert_equal( "Enter a low even number:  " +
                  "Your answer isn't within the expected range " +
                  "(above 0, below 10, and included in [2, 4, 6, 8]).\n" +
                  "?  " +
                  "Your answer isn't within the expected range " +
                  "(above 0, below 10, and included in [2, 4, 6, 8]).\n" +
                  "?  ", @output.string )
  end
  
  def test_reask
    number = 61676
    @input << "Junk!\n" << number << "\n"
    @input.rewind

    answer = @terminal.ask("Favorite number?  ", Integer)
    assert_kind_of(Integer, number)
    assert_instance_of(Fixnum, number)
    assert_equal(number, answer)
    assert_equal( "Favorite number?  " +
                  "You must enter a valid Integer.\n" +
                  "?  ", @output.string )

    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask("Favorite number?  ", Integer) do |q|
      q.responses[:ask_on_error] = :question
      q.responses[:invalid_type] = "Not a valid number!"
    end
    assert_kind_of(Integer, number)
    assert_instance_of(Fixnum, number)
    assert_equal(number, answer)
    assert_equal( "Favorite number?  " +
                  "Not a valid number!\n" +
                  "Favorite number?  ", @output.string )

    @input.truncate(@input.rewind)
    @input << "gen\ngene\n"
    @input.rewind
    @output.truncate(@output.rewind)

    answer = @terminal.ask("Select a mode:  ", [:generate, :gentle])
    assert_instance_of(Symbol, answer)
    assert_equal(:generate, answer)
    assert_equal( "Select a mode:  " +
                  "Ambiguous choice.  " +
                  "Please choose one of [generate, gentle].\n" +
                  "?  ", @output.string )
  end
  
  def test_response_embedding
    @input << "112\n-541\n28\n"
    @input.rewind

    answer = @terminal.ask("Tell me your age.", Integer) do |q|
      q.in = 0..105
      q.responses[:not_in_range] = "Need a <%= @question.answer_type %>" +
                                   " <%= @question.expected_range %>."
    end
    assert_equal(28, answer)
    assert_equal( "Tell me your age.\n" +
                  "Need a Integer included in 0..105.\n" +
                  "?  " +
                  "Need a Integer included in 0..105.\n" +
                  "?  ", @output.string )
  end
  
  def test_say
    @terminal.say("This will have a newline.")
    assert_equal("This will have a newline.\n", @output.string)

    @output.truncate(@output.rewind)

    @terminal.say("This will also have one newline.\n")
    assert_equal("This will also have one newline.\n", @output.string)

    @output.truncate(@output.rewind)

    @terminal.say("This will not have a newline.  ")
    assert_equal("This will not have a newline.  ", @output.string)

    @output.truncate(@output.rewind)
    
    @terminal.say("This will not\n end with a newline. ")
    assert_equal("This will not\n end with a newline. ", @output.string)

    @output.truncate(@output.rewind)

    @terminal.say("This will \nend with a newline.")
    assert_equal("This will \nend with a newline.\n", @output.string)

    @output.truncate(@output.rewind)

    colorized = @terminal.color("This will not have a newline. ", :green)
    @terminal.say(colorized)
    assert_equal("\e[32mThis will not have a newline. \e[0m", @output.string)

    @output.truncate(@output.rewind)

    colorized = @terminal.color("This will have a newline.", :green)
    @terminal.say(colorized)
    assert_equal("\e[32mThis will have a newline.\e[0m\n", @output.string)

    @output.truncate(@output.rewind)

    assert_nothing_raised { @terminal.say(nil) }
    assert_equal("", @output.string)
  end

  def test_say_handles_non_string_argument
    integer = 10
    hash    = { :a => 20 }

    assert_nothing_raised { @terminal.say(integer) }
    assert_equal String(integer), @output.string.chomp

    @output.truncate(@output.rewind)

    assert_nothing_raised { @terminal.say(hash) }
    assert_equal String(hash), @output.string.chomp
  end

  def test_terminal_size
    assert_instance_of(Fixnum, @terminal.terminal_size[0])
    assert_instance_of(Fixnum, @terminal.terminal_size[1])
  end

  def test_type_conversion
    number = 61676
    @input << number << "\n"
    @input.rewind

    answer = @terminal.ask("Favorite number?  ", Integer)
    assert_kind_of(Integer, answer)
    assert_instance_of(Fixnum, answer)
    assert_equal(number, answer)
    
    @input.truncate(@input.rewind)
    number = 1_000_000_000_000_000_000_000_000_000_000
    @input << number << "\n"
    @input.rewind

    answer = @terminal.ask("Favorite number?  ", Integer)
    assert_kind_of(Integer, answer)
    assert_instance_of(Bignum, answer)
    assert_equal(number, answer)

    @input.truncate(@input.rewind)
    number = 10.5002
    @input << number << "\n"
    @input.rewind

    answer = @terminal.ask( "Favorite number?  ",
                            lambda { |n| n.to_f.abs.round } )
    assert_kind_of(Integer, answer)
    assert_instance_of(Fixnum, answer)
    assert_equal(11, answer)

    @input.truncate(@input.rewind)
    animal = :dog
    @input << animal << "\n"
    @input.rewind

    answer = @terminal.ask("Favorite animal?  ", Symbol)
    assert_instance_of(Symbol, answer)
    assert_equal(animal, answer)

    @input.truncate(@input.rewind)
    @input << "16th June 1976\n"
    @input.rewind

    answer = @terminal.ask("Enter your birthday.", Date)
    assert_instance_of(Date, answer)
    assert_equal(16, answer.day)
    assert_equal(6, answer.month)
    assert_equal(1976, answer.year)

    @input.truncate(@input.rewind)
    pattern = "^yes|no$"
    @input << pattern << "\n"
    @input.rewind

    answer = @terminal.ask("Give me a pattern to match with:  ", Regexp)
    assert_instance_of(Regexp, answer)
    assert_equal(/#{pattern}/, answer)

    @input.truncate(@input.rewind)
    @input << "gen\n"
    @input.rewind

    answer = @terminal.ask("Select a mode:  ", [:generate, :run])
    assert_instance_of(Symbol, answer)
    assert_equal(:generate, answer)
  end
  
  def test_validation
    @input << "system 'rm -rf /'\n105\n0b101_001\n"
    @input.rewind

    answer = @terminal.ask("Enter a binary number:  ") do |q|
      q.validate = /\A(?:0b)?[01_]+\Z/
    end
    assert_equal("0b101_001", answer)
    assert_equal( "Enter a binary number:  " +
                  "Your answer isn't valid " +
                  "(must match /\\A(?:0b)?[01_]+\\Z/).\n" +
                  "?  " +
                  "Your answer isn't valid " +
                  "(must match /\\A(?:0b)?[01_]+\\Z/).\n" +
                  "?  ", @output.string )

    @input.truncate(@input.rewind)
    @input << "Gray II, James Edward\n" +
              "Gray, Dana Ann Leslie\n" +
              "Gray, James Edward\n"
    @input.rewind

    answer = @terminal.ask("Your name?  ") do |q|
      q.validate = lambda do |name|
        names = name.split(/,\s*/)
        return false unless names.size == 2
        return false if names.first =~ /\s/
        names.last.split.size == 2
      end
    end
    assert_equal("Gray, James Edward", answer)
  end
  
  def test_whitespace
    @input << "  A   lot\tof  \t  space\t  \there!   \n"
    @input.rewind
    
    answer = @terminal.ask("Enter a whitespace filled string:  ") do |q|
      q.whitespace = :chomp
    end
    assert_equal("  A   lot\tof  \t  space\t  \there!   ", answer)

    @input.rewind

    answer = @terminal.ask("Enter a whitespace filled string:  ")
    assert_equal("A   lot\tof  \t  space\t  \there!", answer)

    @input.rewind

    answer = @terminal.ask("Enter a whitespace filled string:  ") do |q|
      q.whitespace = :strip_and_collapse
    end
    assert_equal("A lot of space here!", answer)

    @input.rewind

    answer = @terminal.ask("Enter a whitespace filled string:  ") do |q|
      q.whitespace = :remove
    end
    assert_equal("Alotofspacehere!", answer)

    @input.rewind

    answer = @terminal.ask("Enter a whitespace filled string:  ") do |q|
      q.whitespace = :none
    end
    assert_equal("  A   lot\tof  \t  space\t  \there!   \n", answer)
  end
  
  def test_wrap
    @terminal.wrap_at = 80
    
    @terminal.say("This is a very short line.")
    assert_equal("This is a very short line.\n", @output.string)
    
    @output.truncate(@output.rewind)

    @terminal.say( "This is a long flowing paragraph meant to span " +
                   "several lines.  This text should definitely be " +
                   "wrapped at the set limit, in the result.  Your code " +
                   "does well with things like this.\n\n" +
                   "  * This is a simple embedded list.\n" +
                   "  * You're code should not mess with this...\n" +
                       "  * Because it's already formatted correctly and " +
                   "does not\n" +
                   "    exceed the limit!" )
    assert_equal( "This is a long flowing paragraph meant to span " +
                  "several lines.  This text should\n" +
                  "definitely be wrapped at the set limit, in the " +
                  "result.  Your code does well with\n" +
                  "things like this.\n\n" +
                  "  * This is a simple embedded list.\n" +
                  "  * You're code should not mess with this...\n" +
                  "  * Because it's already formatted correctly and does " +
                  "not\n" +
                  "    exceed the limit!\n", @output.string )

    @output.truncate(@output.rewind)

    @terminal.say("-=" * 50)
    assert_equal(("-=" * 40 + "\n") + ("-=" * 10 + "\n"), @output.string)
  end
  
  def test_track_eof
    assert_raise(EOFError) { @terminal.ask("Any input left?  ") }
    
    # turn EOF tracking
    old_setting = HighLine.track_eof?
    assert_nothing_raised(Exception) { HighLine.track_eof = false }
    begin
      @terminal.ask("And now?  ")  # this will still blow up, nothing available
    rescue
      assert_not_equal(EOFError, $!.class)  # but HighLine's safe guards are off
    end
    HighLine.track_eof = old_setting
  end
  
  def test_version
    assert_not_nil(HighLine::VERSION)
    assert_instance_of(String, HighLine::VERSION)
    assert(HighLine::VERSION.frozen?)
    assert_match(/\A\d+\.\d+\.\d+\Z/, HighLine::VERSION)
  end
end
