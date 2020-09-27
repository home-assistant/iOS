# tc_string_extension.rb
#
#  Created by Richard LeBer 2011-06-27
#
#  This is Free Software.  See LICENSE and COPYING for details.

require "test/unit"

require "highline"
require "stringio"
require "string_methods"

class TestStringExtension < Test::Unit::TestCase
  def setup
    HighLine.colorize_strings
    @string = "string"
  end

  include StringMethods

  def test_Highline_String_is_yaml_serializable
    require 'yaml'
    unless Gem::Version.new(YAML::VERSION) < Gem::Version.new("2.0.2")
      highline_string = HighLine::String.new("Yaml didn't messed with HighLine::String")
      yaml_highline_string = highline_string.to_yaml
      yaml_loaded_string = YAML.load(yaml_highline_string)

      assert_equal "Yaml didn't messed with HighLine::String", yaml_loaded_string
      assert_equal highline_string, yaml_loaded_string
      assert_instance_of HighLine::String, yaml_loaded_string
    end
  end
end
