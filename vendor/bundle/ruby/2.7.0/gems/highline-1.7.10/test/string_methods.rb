# string_methods.rb
#
#  Created by Richard LeBer 2011-06-27
#
#  This is Free Software.  See LICENSE and COPYING for details.
#
#  String class convenience methods

module StringMethods  
  def test_color
    assert_equal("\e[34mstring\e[0m", @string.color(:blue))
    assert_equal("\e[1m\e[47mstring\e[0m", @string.color(:bold,:on_white))
    assert_equal("\e[45mstring\e[0m", @string.on(:magenta))
    assert_equal("\e[36mstring\e[0m", @string.cyan)
    assert_equal("\e[41m\e[5mstring\e[0m\e[0m", @string.blink.on_red)
    assert_equal("\e[38;5;137mstring\e[0m", @string.color(:rgb_906030))
    assert_equal("\e[38;5;101mstring\e[0m", @string.rgb('606030'))
    assert_equal("\e[38;5;107mstring\e[0m", @string.rgb('60','90','30'))
    assert_equal("\e[38;5;107mstring\e[0m", @string.rgb(96,144,48))
    assert_equal("\e[38;5;173mstring\e[0m", @string.rgb_c06030)
    assert_equal("\e[48;5;137mstring\e[0m", @string.color(:on_rgb_906030))
    assert_equal("\e[48;5;101mstring\e[0m", @string.on_rgb('606030'))
    assert_equal("\e[48;5;107mstring\e[0m", @string.on_rgb('60','90','30'))
    assert_equal("\e[48;5;107mstring\e[0m", @string.on_rgb(96,144,48))
    assert_equal("\e[48;5;173mstring\e[0m", @string.on_rgb_c06030)
  end
  
  def test_uncolor
    colored_string = HighLine::String("\e[38;5;137mstring\e[0m")
    assert_equal "string", colored_string.uncolor
  end
end
