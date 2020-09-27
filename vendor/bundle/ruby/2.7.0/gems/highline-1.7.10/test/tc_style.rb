# tc_style.rb
#
#  Created by Richard LeBer on 2011-06-11.
#
#  This is Free Software.  See LICENSE and COPYING for details.

require "test/unit"

require "highline"
require "stringio"

class TestStyle < Test::Unit::TestCase
  
  def setup
    @input    = StringIO.new
    @output   = StringIO.new
    @terminal = HighLine.new(@input, @output)  
    @style1   = HighLine::Style.new(:name=>:foo, :code=>"\e[99m", :rgb=>[1,2,3])
    @style2   = HighLine::Style.new(:name=>:lando, :code=>"\e[98m")
    @style3   = HighLine::Style.new(:name=>[:foo, :lando], :list=>[:foo, :lando])
    @style4   = HighLine::Style(:rgb_654321)
  end
  
  def teardown
    # HighLine::Style.clear_index
  end
  
  def test_style_method
    # Retrieve a style from an existing Style (no new Style created)
    new_style = @style1.dup # This will replace @style1 in the indexes
    s = HighLine.Style(@style1)
    assert_instance_of HighLine::Style, s
    assert_same new_style, s # i.e. s===the latest style created, but not the one searched for

    # Retrieve a style from a new Style (no new Style created)
    s2 = HighLine::Style.new(:name=>:bar, :code=>"\e[97m")
    s = HighLine.Style(s2)
    assert_instance_of HighLine::Style, s
    assert_same s2, s

    # Create a builtin style from an existing ANSI escape string
    s = HighLine.Style("\e[1m")
    assert_instance_of HighLine::Style, s
    assert_nil s.list
    assert_equal "\e[1m", s.code
    assert_equal :bold, s.name

    # Create a builtin style from a new ANSI escape string
    s = HighLine.Style("\e[96m")
    assert_instance_of HighLine::Style, s
    assert_nil s.list
    assert_equal "\e[96m", s.code

    # Create a builtin style from a symbol
    s = HighLine.Style(:red)
    assert_instance_of HighLine::Style, s
    assert_nil s.list
    assert_equal :red, s.name

    # Retrieve an existing style by name (no new Style created)
    s = HighLine.Style(@style2.name)
    assert_instance_of HighLine::Style, s
    assert_same @style2, s
    
    # See below for color scheme tests
    
    # Create style from a Hash
    s = HighLine.Style(:name=>:han, :code=>"blah", :rgb=>'phooey')
    assert_instance_of HighLine::Style, s
    assert_equal :han, s.name
    assert_equal "blah", s.code
    assert_equal "phooey", s.rgb
    
    # Create style from an RGB foreground color code
    s = HighLine.Style(:rgb_1f2e3d)
    assert_instance_of HighLine::Style, s
    assert_equal :rgb_1f2e3d, s.name
    assert_equal "\e[38;5;23m", s.code # Trust me; more testing below
    assert_equal [31,46,61], s.rgb     # 0x1f==31, 0x2e==46, 0x3d=61
    
    # Create style from an RGB background color code
    s = HighLine.Style(:on_rgb_1f2e3d)
    assert_instance_of HighLine::Style, s
    assert_equal :on_rgb_1f2e3d, s.name
    assert_equal "\e[48;5;23m", s.code # Trust me; more testing below
    assert_equal [31,46,61], s.rgb     # 0x1f==31, 0x2e==46, 0x3d=61

    # Create a style list
    s1 = HighLine.Style(:bold, :red)
    assert_instance_of HighLine::Style, s1
    assert_equal [:bold, :red], s1.list
    
    # Find an existing style list
    s2 = HighLine.Style(:bold, :red)
    assert_instance_of HighLine::Style, s2
    assert_same s1, s2

    # Create a style list with nils
    s1 = HighLine.Style(:underline, nil, :blue)
    assert_instance_of HighLine::Style, s1
    assert_equal [:underline, :blue], s1.list
    
    # Raise an error for an undefined style
    assert_raise(::NameError) { HighLine.Style(:fubar) }
  end
  
  def test_no_color_scheme
    HighLine.color_scheme = nil
    assert_raise(::NameError) { HighLine.Style(:critical) }
  end
  
  def test_with_color_scheme
    HighLine.color_scheme = HighLine::SampleColorScheme.new
    s = HighLine.Style(:critical)
    assert_instance_of HighLine::Style, s
    assert_equal :critical, s.name
    assert_equal [:yellow, :on_red], s.list
  end
  
  def test_builtin_foreground_colors_defined
    HighLine::COLORS.each do |color|
      style = HighLine.const_get(color+'_STYLE')
      assert_instance_of HighLine::Style, style
      assert_equal color.downcase.to_sym, style.name
      assert style.builtin
      code = HighLine.const_get(color)
      assert_instance_of String, code, "Bad code for #{color}"
    end
  end
  
  def test_builtin_background_colors_defined
    HighLine::COLORS.each do |color|
      style = HighLine.const_get('ON_' + color+'_STYLE')
      assert_instance_of HighLine::Style, style
      assert_equal "ON_#{color}".downcase.to_sym, style.name
      assert style.builtin
      code = HighLine.const_get('ON_' + color)
      assert_instance_of String, code, "Bad code for ON_#{color}"
    end
  end
  
  def test_builtin_styles_defined
    HighLine::STYLES.each do |style_constant|
      style = HighLine.const_get(style_constant+'_STYLE')
      assert_instance_of HighLine::Style, style
      assert_equal style_constant.downcase.to_sym, style.name
      assert style.builtin
      code = HighLine.const_get(style_constant)
      assert_instance_of String, code, "Bad code for #{style_constant}"
    end
  end
  
  def test_index
    # Add a Style with a new name and code
    assert_nil HighLine::Style.list[:s1]
    assert_nil HighLine::Style.code_index['foo']
    s1 = HighLine::Style.new(:name=>:s1, :code=>'foo')
    assert_not_nil HighLine::Style.list[:s1]
    assert_same s1, HighLine::Style.list[:s1]
    assert_equal :s1, HighLine::Style.list[:s1].name
    assert_equal 'foo', HighLine::Style.list[:s1].code
    styles = HighLine::Style.list.size
    codes  = HighLine::Style.code_index.size
    assert_instance_of Array, HighLine::Style.code_index['foo']
    assert_equal 1, HighLine::Style.code_index['foo'].size
    assert_same s1, HighLine::Style.code_index['foo'].last
    assert_equal :s1, HighLine::Style.code_index['foo'].last.name
    assert_equal 'foo', HighLine::Style.code_index['foo'].last.code

    # Add another Style with a new name and code
    assert_nil HighLine::Style.list[:s2]
    assert_nil HighLine::Style.code_index['bar']
    s2 = HighLine::Style.new(:name=>:s2, :code=>'bar')
    assert_equal styles+1, HighLine::Style.list.size
    assert_equal codes+1,  HighLine::Style.code_index.size
    assert_not_nil HighLine::Style.list[:s2]
    assert_same s2, HighLine::Style.list[:s2]
    assert_equal :s2, HighLine::Style.list[:s2].name
    assert_equal 'bar', HighLine::Style.list[:s2].code
    assert_instance_of Array, HighLine::Style.code_index['bar']
    assert_equal 1, HighLine::Style.code_index['bar'].size
    assert_same s2, HighLine::Style.code_index['bar'].last
    assert_equal :s2, HighLine::Style.code_index['bar'].last.name
    assert_equal 'bar', HighLine::Style.code_index['bar'].last.code
    
    # Add a Style with an existing name
    s3_before = HighLine::Style.list[:s2]
    assert_not_nil HighLine::Style.list[:s2]
    assert_nil HighLine::Style.code_index['baz']
    s3 = HighLine::Style.new(:name=>:s2, :code=>'baz')
    assert_not_same s2, s3
    assert_not_same s3_before, s3
    assert_equal styles+1, HighLine::Style.list.size
    assert_equal codes+2,  HighLine::Style.code_index.size
    assert_not_nil HighLine::Style.list[:s2]
    assert_same s3, HighLine::Style.list[:s2]
    assert_not_same s2, HighLine::Style.list[:s2]
    assert_equal :s2, HighLine::Style.list[:s2].name
    assert_equal 'baz', HighLine::Style.list[:s2].code
    assert_instance_of Array, HighLine::Style.code_index['baz']
    assert_equal 1, HighLine::Style.code_index['baz'].size
    assert_same s3, HighLine::Style.code_index['baz'].last
    assert_equal :s2, HighLine::Style.code_index['baz'].last.name
    assert_equal 'baz', HighLine::Style.code_index['baz'].last.code

    # Add a Style with an existing code
    assert_equal 1, HighLine::Style.code_index['baz'].size
    s4 = HighLine::Style.new(:name=>:s4, :code=>'baz')
    assert_equal styles+2, HighLine::Style.list.size
    assert_equal codes+2,  HighLine::Style.code_index.size
    assert_not_nil HighLine::Style.list[:s4]
    assert_same s4, HighLine::Style.list[:s4]
    assert_equal :s4, HighLine::Style.list[:s4].name
    assert_equal 'baz', HighLine::Style.list[:s4].code
    assert_equal 2, HighLine::Style.code_index['baz'].size
    assert_same s3, HighLine::Style.code_index['baz'].first # Unchanged from last time
    assert_equal :s2, HighLine::Style.code_index['baz'].first.name # Unchanged from last time
    assert_equal 'baz', HighLine::Style.code_index['baz'].first.code # Unchanged from last time
    assert_same s4, HighLine::Style.code_index['baz'].last
    assert_equal :s4, HighLine::Style.code_index['baz'].last.name
    assert_equal 'baz', HighLine::Style.code_index['baz'].last.code
  end
  
  def test_rgb_hex
    assert_equal "abcdef", HighLine::Style.rgb_hex("abcdef")
    assert_equal "ABCDEF", HighLine::Style.rgb_hex("AB","CD","EF")
    assert_equal "010203", HighLine::Style.rgb_hex(1,2,3)
    assert_equal "123456", HighLine::Style.rgb_hex(18,52,86)
  end
  
  def test_rgb_parts
    assert_equal [1,2,3], HighLine::Style.rgb_parts("010203")
    assert_equal [18,52,86], HighLine::Style.rgb_parts("123456")
  end
  
  def test_rgb
    s = HighLine::Style.rgb(1, 2, 3)
    assert_instance_of HighLine::Style, s
    assert_equal :rgb_010203, s.name
    assert_equal [1,2,3], s.rgb
    assert_equal "\e[38;5;16m", s.code

    s = HighLine::Style.rgb("12", "34","56")
    assert_instance_of HighLine::Style, s
    assert_equal :rgb_123456, s.name
    assert_equal [0x12, 0x34, 0x56], s.rgb
    assert_equal "\e[38;5;24m", s.code

    s = HighLine::Style.rgb("abcdef")
    assert_instance_of HighLine::Style, s
    assert_equal :rgb_abcdef, s.name
    assert_equal [0xab, 0xcd, 0xef], s.rgb
    assert_equal "\e[38;5;189m", s.code
  end
  
  def test_rgb_number
    # ANSI RGB coding splits 0..255 into equal sixths, and then the 
    # red green and blue are encoded in base 6, plus 16, i.e.
    # 16 + 36*(red_level) + 6*(green_level) + blue_level,
    # where each of red_level, green_level, and blue_level are in
    # the range 0..5
    
    # This test logic works because 42 is just below 1/6 of 255,
    # and 43 is just above
    
    assert_equal 16 + 0*36 + 0*6 + 0, HighLine::Style.rgb_number(  0,  0,  0)
    assert_equal 16 + 0*36 + 0*6 + 0, HighLine::Style.rgb_number(  0,  0, 42)
    assert_equal 16 + 0*36 + 0*6 + 1, HighLine::Style.rgb_number(  0,  0, 43)

    assert_equal 16 + 0*36 + 0*6 + 0, HighLine::Style.rgb_number(  0, 42,  0)
    assert_equal 16 + 0*36 + 0*6 + 0, HighLine::Style.rgb_number(  0, 42, 42)
    assert_equal 16 + 0*36 + 0*6 + 1, HighLine::Style.rgb_number(  0, 42, 43)

    assert_equal 16 + 0*36 + 1*6 + 0, HighLine::Style.rgb_number(  0, 43,  0)
    assert_equal 16 + 0*36 + 1*6 + 0, HighLine::Style.rgb_number(  0, 43, 42)
    assert_equal 16 + 0*36 + 1*6 + 1, HighLine::Style.rgb_number(  0, 43, 43)

    assert_equal 16 + 0*36 + 0*6 + 0, HighLine::Style.rgb_number( 42,  0,  0)
    assert_equal 16 + 0*36 + 0*6 + 0, HighLine::Style.rgb_number( 42,  0, 42)
    assert_equal 16 + 0*36 + 0*6 + 1, HighLine::Style.rgb_number( 42,  0, 43)

    assert_equal 16 + 0*36 + 0*6 + 0, HighLine::Style.rgb_number( 42, 42,  0)
    assert_equal 16 + 0*36 + 0*6 + 0, HighLine::Style.rgb_number( 42, 42, 42)
    assert_equal 16 + 0*36 + 0*6 + 1, HighLine::Style.rgb_number( 42, 42, 43)

    assert_equal 16 + 0*36 + 1*6 + 0, HighLine::Style.rgb_number( 42, 43,  0)
    assert_equal 16 + 0*36 + 1*6 + 0, HighLine::Style.rgb_number( 42, 43, 42)
    assert_equal 16 + 0*36 + 1*6 + 1, HighLine::Style.rgb_number( 42, 43, 43)

    assert_equal 16 + 1*36 + 0*6 + 0, HighLine::Style.rgb_number( 43,  0,  0)
    assert_equal 16 + 1*36 + 0*6 + 0, HighLine::Style.rgb_number( 43,  0, 42)
    assert_equal 16 + 1*36 + 0*6 + 1, HighLine::Style.rgb_number( 43,  0, 43)

    assert_equal 16 + 1*36 + 0*6 + 0, HighLine::Style.rgb_number( 43, 42,  0)
    assert_equal 16 + 1*36 + 0*6 + 0, HighLine::Style.rgb_number( 43, 42, 42)
    assert_equal 16 + 1*36 + 0*6 + 1, HighLine::Style.rgb_number( 43, 42, 43)

    assert_equal 16 + 1*36 + 1*6 + 0, HighLine::Style.rgb_number( 43, 43,  0)
    assert_equal 16 + 1*36 + 1*6 + 0, HighLine::Style.rgb_number( 43, 43, 42)
    assert_equal 16 + 1*36 + 1*6 + 1, HighLine::Style.rgb_number( 43, 43, 43)
    
    assert_equal 16 + 5*36 + 5*6 + 5, HighLine::Style.rgb_number(255,255,255)
  end
  
  def test_ansi_rgb_to_hex
    assert_equal "000000", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 0)
    assert_equal "000000", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 0)
    assert_equal "00002b", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 1)

    assert_equal "000000", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 0)
    assert_equal "000000", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 0)
    assert_equal "00002b", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 1)

    assert_equal "002b00", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 1*6 + 0)
    assert_equal "002b00", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 1*6 + 0)
    assert_equal "002b2b", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 1*6 + 1)

    assert_equal "000000", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 0)
    assert_equal "000000", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 0)
    assert_equal "00002b", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 1)

    assert_equal "000000", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 0)
    assert_equal "000000", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 0)
    assert_equal "00002b", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 0*6 + 1)

    assert_equal "002b00", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 1*6 + 0)
    assert_equal "002b00", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 1*6 + 0)
    assert_equal "002b2b", HighLine::Style.ansi_rgb_to_hex(16 + 0*36 + 1*6 + 1)

    assert_equal "2b0000", HighLine::Style.ansi_rgb_to_hex(16 + 1*36 + 0*6 + 0)
    assert_equal "2b0000", HighLine::Style.ansi_rgb_to_hex(16 + 1*36 + 0*6 + 0)
    assert_equal "2b002b", HighLine::Style.ansi_rgb_to_hex(16 + 1*36 + 0*6 + 1)

    assert_equal "2b0000", HighLine::Style.ansi_rgb_to_hex(16 + 1*36 + 0*6 + 0)
    assert_equal "2b0000", HighLine::Style.ansi_rgb_to_hex(16 + 1*36 + 0*6 + 0)
    assert_equal "2b002b", HighLine::Style.ansi_rgb_to_hex(16 + 1*36 + 0*6 + 1)

    assert_equal "2b2b00", HighLine::Style.ansi_rgb_to_hex(16 + 1*36 + 1*6 + 0)
    assert_equal "2b2b00", HighLine::Style.ansi_rgb_to_hex(16 + 1*36 + 1*6 + 0)
    assert_equal "2b2b2b", HighLine::Style.ansi_rgb_to_hex(16 + 1*36 + 1*6 + 1)
    
    # 0xd5 is the smallest number where n/255.0*6.0 > 5
    assert_equal "d5d5d5", HighLine::Style.ansi_rgb_to_hex(16 + 5*36 + 5*6 + 5)
  end
  
  def test_list
    list_size = HighLine::Style.list.size
    # Add a Style with a new name and code
    assert_nil HighLine::Style.list[:s5]
    s5 = HighLine::Style.new(:name=>:s5, :code=>'foo')
    assert_not_nil HighLine::Style.list[:s5]
    assert_equal list_size+1, HighLine::Style.list.size
    assert_not_nil HighLine::Style.list[:s5]
    assert_same s5, HighLine::Style.list[:s5]
    assert_equal :s5, HighLine::Style.list[:s5].name
    assert_equal 'foo', HighLine::Style.list[:s5].code

    # Add another Style with a new name and code
    assert_nil HighLine::Style.list[:s6]
    s6 = HighLine::Style.new(:name=>:s6, :code=>'bar')
    assert_equal list_size+2, HighLine::Style.list.size
    assert_not_nil HighLine::Style.list[:s6]
    assert_same s6, HighLine::Style.list[:s6]
    assert_equal :s6, HighLine::Style.list[:s6].name
    assert_equal 'bar', HighLine::Style.list[:s6].code
    
    # Add a Style with an existing name
    s7 = HighLine::Style.new(:name=>:s6, :code=>'baz')
    assert_equal list_size+2, HighLine::Style.list.size # No net addition to list
    assert_not_nil HighLine::Style.list[:s6]
    assert_same s7, HighLine::Style.list[:s6] # New one replaces old one
    assert_not_same s6, HighLine::Style.list[:s6]
    assert_equal :s6, HighLine::Style.list[:s6].name
    assert_equal 'baz', HighLine::Style.list[:s6].code
  end
  
  def test_code_index
    list_size = HighLine::Style.code_index.size
    
    # Add a Style with a new name and code
    assert_nil HighLine::Style.code_index['chewie']
    HighLine::Style.new(:name=>:s8, :code=>'chewie')
    assert_equal list_size+1, HighLine::Style.code_index.size
    assert_instance_of Array, HighLine::Style.code_index['chewie']
    assert_equal 1, HighLine::Style.code_index['chewie'].size
    assert_equal :s8, HighLine::Style.code_index['chewie'].last.name
    assert_equal 'chewie', HighLine::Style.code_index['chewie'].last.code

    # Add another Style with a new name and code
    assert_nil HighLine::Style.code_index['c3po']
    HighLine::Style.new(:name=>:s9, :code=>'c3po')
    assert_equal list_size+2,  HighLine::Style.code_index.size
    assert_instance_of Array, HighLine::Style.code_index['c3po']
    assert_equal 1, HighLine::Style.code_index['c3po'].size
    assert_equal :s9, HighLine::Style.code_index['c3po'].last.name
    assert_equal 'c3po', HighLine::Style.code_index['c3po'].last.code

    # Add a Style with an existing code
    assert_equal 1, HighLine::Style.code_index['c3po'].size
    HighLine::Style.new(:name=>:s10, :code=>'c3po')
    assert_equal list_size+2,  HighLine::Style.code_index.size
    assert_equal 2, HighLine::Style.code_index['c3po'].size
    assert_equal :s10, HighLine::Style.code_index['c3po'].last.name
    assert_equal 'c3po', HighLine::Style.code_index['c3po'].last.code
  end
  
  def test_uncolor
    # Normal color
    assert_equal "This should be reverse underlined magenta!\n",
        HighLine::Style.uncolor("This should be \e[7m\e[4m\e[35mreverse underlined magenta\e[0m!\n" )

    # RGB color
    assert_equal "This should be rgb_906030!\n",
        HighLine::Style.uncolor("This should be \e[38;5;137mrgb_906030\e[0m!\n" )
  end
  
  def test_color
    assert_equal "\e[99mstring\e[0m", @style1.color("string") # simple style
    assert_equal "\e[99m\e[98mstring\e[0m", @style3.color("string") # Style list
  end
  
  def test_code
    assert_equal "\e[99m", @style1.code # simple style
    assert_equal "\e[99m\e[98m", @style3.code # Style list
  end
  
  def test_red
    assert_equal 0x65, @style4.red
    assert_equal 0, HighLine::Style(:none).red # Probably reliable
    assert_equal 0, HighLine::Style(:black).red # Probably reliable
    assert_equal 255, HighLine::Style(:bright_magenta).red # Seems to be reliable
    assert_equal 255, HighLine::Style(:on_none).red # Probably reliable
  end
  
  def test_green
    assert_equal 0x43, @style4.green
    assert_equal 0, HighLine::Style(:none).green # Probably reliable
    assert_equal 0, HighLine::Style(:black).green # Probably reliable
    assert       240 <= HighLine::Style(:bright_cyan).green # Probably reliable
    assert_equal 255, HighLine::Style(:on_none).green # Probably reliable
  end
  
  def test_blue
    assert_equal 0x21, @style4.blue
    assert_equal 0, HighLine::Style(:none).blue # Probably reliable
    assert_equal 0, HighLine::Style(:black).blue # Probably reliable
    assert_equal 255, HighLine::Style(:bright_blue).blue # Probably reliable
    assert_equal 255, HighLine::Style(:on_none).blue # Probably reliable
  end
  
  def test_builtin
    assert HighLine::Style(:red).builtin
    assert !@style1.builtin
  end
  
  def test_variant
    style1_name = @style1.name
    style1_code = @style1.code
    style1_rgb = @style1.rgb
    
    s1 = @style1.variant(:new_foo1, :code=>'abracadabra')
    assert_instance_of HighLine::Style, s1
    assert_not_same @style1, s1 # This is a copy
    assert_equal :new_foo1, s1.name # Changed
    assert_equal 'abracadabra', s1.code # Changed
    assert_equal [1,2,3], s1.rgb # Unchanged
    
    s2 = @style1.variant(:new_foo2, :increment=>-15)
    assert_instance_of HighLine::Style, s2
    assert_not_same @style1, s2     # This is a copy
    assert_equal :new_foo2, s2.name # Changed
    assert_equal "\e[84m", s2.code  # 99 (original code) - 15
    assert_equal [1,2,3], s2.rgb    # Unchanged
    
    s3 = @style1.variant(:new_foo3, :code=>"\e[55m", :increment=>15)
    assert_instance_of HighLine::Style, s3
    assert_not_same @style1, s3     # This is a copy
    assert_equal :new_foo3, s3.name # Changed
    assert_equal "\e[70m", s3.code  # 99 (new code) + 15
    assert_equal [1,2,3], s3.rgb    # Unchanged
    
    s4 = @style1.variant(:new_foo4, :code=>"\e[55m", :increment=>15, :rgb=>"blah")
    assert_instance_of HighLine::Style, s4
    assert_not_same @style1, s4     # This is a copy
    assert_equal :new_foo4, s4.name # Changed
    assert_equal "\e[70m", s4.code  # 99 (new code) + 15
    assert_equal 'blah', s4.rgb     # Changed

    s5 = @style1.variant(:new_foo5)
    assert_instance_of HighLine::Style, s5
    assert_not_same @style1, s5     # This is a copy
    assert_equal :new_foo5, s5.name # Changed
    assert_equal "\e[99m", s5.code  # Unchanged
    assert_equal [1,2,3], s5.rgb    # Unchanged

    # No @style1's have been harmed in the running of this test
    assert_equal style1_name, @style1.name
    assert_equal style1_code, @style1.code
    assert_equal style1_rgb,  @style1.rgb
    
    assert_raise(::RuntimeError) { @style3.variant(:new_foo6) } # Can't create a variant of a list style
  end
  
  def test_on
    style1_name = @style1.name
    style1_code = @style1.code
    style1_rgb = @style1.rgb
    
    s1 = @style1.on
    assert_instance_of HighLine::Style, s1
    assert_not_same @style1, s1     # This is a copy
    assert_equal :on_foo, s1.name   # Changed
    assert_equal "\e[109m", s1.code # Changed
    assert_equal [1,2,3], s1.rgb    # Unchanged

    # No @style1's have been harmed in the running of this test
    assert_equal style1_name, @style1.name
    assert_equal style1_code, @style1.code
    assert_equal style1_rgb,  @style1.rgb
    
    assert_raise(::RuntimeError) { @style3.on } # Can't create a variant of a list style
  end
  
  def test_bright
    style1_name = @style1.name
    style1_code = @style1.code
    style1_rgb = @style1.rgb
    
    s1 = @style1.bright
    assert_instance_of HighLine::Style, s1
    assert_not_same @style1, s1         # This is a copy
    assert_equal :bright_foo, s1.name   # Changed
    assert_equal "\e[159m", s1.code     # Changed
    assert_equal [129,130,131], s1.rgb  # Changed

    # No @style1's have been harmed in the running of this test
    assert_equal style1_name, @style1.name
    assert_equal style1_code, @style1.code
    assert_equal style1_rgb,  @style1.rgb
    
    s2_base = HighLine::Style.new(:name=>:leia, :code=>"\e[92m", :rgb=>[0,0,14])
    s2 = s2_base.bright
    assert_instance_of HighLine::Style, s2
    assert_not_same s2_base, s2         # This is a copy
    assert_equal :bright_leia, s2.name  # Changed
    assert_equal "\e[152m", s2.code     # Changed
    assert_equal [0,0,142], s2.rgb      # Changed
    
    s3_base = HighLine::Style.new(:name=>:luke, :code=>"\e[93m", :rgb=>[20,21,0])
    s3 = s3_base.bright
    assert_instance_of HighLine::Style, s3
    assert_not_same s3_base, s3         # This is a copy
    assert_equal :bright_luke, s3.name  # Changed
    assert_equal "\e[153m", s3.code     # Changed
    assert_equal [148,149,0], s3.rgb    # Changed
    
    s4_base = HighLine::Style.new(:name=>:r2d2, :code=>"\e[94m", :rgb=>[0,0,0])
    s4 = s4_base.bright
    assert_instance_of HighLine::Style, s4
    assert_not_same s4_base, s4         # This is a copy
    assert_equal :bright_r2d2, s4.name  # Changed
    assert_equal "\e[154m", s4.code     # Changed
    assert_equal [128,128,128], s4.rgb  # Changed; special case
    
    assert_raise(::RuntimeError) { @style3.bright } # Can't create a variant of a list style
  end

  def test_light_do_the_same_as_bright
    bright_style = @style1.bright
    light_style  = @style1.light

    assert_not_equal bright_style, light_style
    assert_equal :bright_foo, bright_style.name
    assert_equal :light_foo, light_style.name
    assert_equal bright_style.code, light_style.code
    assert_equal bright_style.rgb, light_style.rgb
  end
end
