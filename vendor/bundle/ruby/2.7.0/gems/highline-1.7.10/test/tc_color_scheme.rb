# tc_color_scheme.rb
#
#  Created by Jeremy Hinegardner on 2007-01-24.  
#  Copyright 2007 Jeremy Hinegardner. All rights reserved.
#
#  This is Free Software.  See LICENSE and COPYING for details.

require "test/unit"

require "highline"
require "stringio"

class TestColorScheme < Test::Unit::TestCase
  def setup
    @input    = StringIO.new
    @output   = StringIO.new
    @terminal = HighLine.new(@input, @output)
    
    @old_color_scheme = HighLine.color_scheme
  end
  
  def teardown
    HighLine.color_scheme = @old_color_scheme
  end

  def test_using_color_scheme
    assert_equal(false,HighLine.using_color_scheme?)

    HighLine.color_scheme = HighLine::ColorScheme.new
    assert_equal(true,HighLine.using_color_scheme?)
  end

  def test_scheme
    HighLine.color_scheme = HighLine::SampleColorScheme.new

    @terminal.say("This should be <%= color('warning yellow', :warning) %>.")
    assert_equal("This should be \e[1m\e[33mwarning yellow\e[0m.\n",@output.string)
    @output.rewind
    
    @terminal.say("This should be <%= color('warning yellow', 'warning') %>.")
    assert_equal("This should be \e[1m\e[33mwarning yellow\e[0m.\n",@output.string)
    @output.rewind

    @terminal.say("This should be <%= color('warning yellow', 'WarNing') %>.")
    assert_equal("This should be \e[1m\e[33mwarning yellow\e[0m.\n",@output.string)
    @output.rewind
    
    # Check that keys are available, and as expected
    assert_equal ["critical", "error", "warning", "notice", "info", "debug", "row_even", "row_odd"].sort,
                 HighLine.color_scheme.keys.sort
    
    # Color scheme doesn't care if we use symbols or strings, and is case-insensitive
    warning1 = HighLine.color_scheme[:warning]
    warning2 = HighLine.color_scheme["warning"]
    warning3 = HighLine.color_scheme[:wArning]
    warning4 = HighLine.color_scheme["warniNg"]
    assert_instance_of HighLine::Style, warning1
    assert_instance_of HighLine::Style, warning2
    assert_instance_of HighLine::Style, warning3
    assert_instance_of HighLine::Style, warning4
    assert_equal warning1, warning2
    assert_equal warning1, warning3
    assert_equal warning1, warning4

    # Nonexistent keys return nil
    assert_nil HighLine.color_scheme[:nonexistent]
    
    # Same as above, for definitions
    defn1 = HighLine.color_scheme.definition(:warning)
    defn2 = HighLine.color_scheme.definition("warning")
    defn3 = HighLine.color_scheme.definition(:wArning)
    defn4 = HighLine.color_scheme.definition("warniNg")
    assert_instance_of Array, defn1
    assert_instance_of Array, defn2
    assert_instance_of Array, defn3
    assert_instance_of Array, defn4
    assert_equal [:bold, :yellow], defn1
    assert_equal [:bold, :yellow], defn2
    assert_equal [:bold, :yellow], defn3
    assert_equal [:bold, :yellow], defn4
    assert_nil HighLine.color_scheme.definition(:nonexistent)
    
    color_scheme_hash = HighLine.color_scheme.to_hash
    assert_instance_of Hash, color_scheme_hash
    assert_equal ["critical", "error", "warning", "notice", "info", "debug", "row_even", "row_odd"].sort,
                 color_scheme_hash.keys.sort
    assert_instance_of Array, HighLine.color_scheme.definition(:warning)
    assert_equal [:bold, :yellow], HighLine.color_scheme.definition(:warning)

    # turn it back off, should raise an exception
    HighLine.color_scheme = @old_color_scheme
    assert_raises(NameError) {
      @terminal.say("This should be <%= color('nothing at all', :error) %>.")
    }
  end
end 
