# tc_highline_string.rb
#
#  Created by Richard LeBer 2011-06-27
#
#  This is Free Software.  See LICENSE and COPYING for details.

require "test/unit"

require "highline"
require "stringio"
require "string_methods"

class TestHighLineString < Test::Unit::TestCase
  def setup
    @string = HighLine::String.new("string")
  end

  def test_string_class
    # Basic constructor
    assert_equal HighLine::String, @string.class
    assert_equal "string", @string
    
    # Alternative constructor method
    new_string = HighLine::String("string")
    assert_equal HighLine::String, new_string.class
    assert_equal @string, new_string
    
    # String methods work
    assert_equal 6, @string.size
    assert_equal "STRING", @string.upcase
  end

  include StringMethods
  
  def test_string_class_is_unchanged
    assert_raise(::NoMethodError) { "string".color(:blue) }
  end
end
