# color_scheme.rb
#
# Created by Richard LeBer on 2011-06-27.
# Copyright 2011.  All rights reserved
#
# This is Free Software.  See LICENSE and COPYING for details

class HighLine

  def self.Style(*args)
    args = args.compact.flatten
    if args.size==1
      arg = args.first
      if arg.is_a?(Style)
        Style.list[arg.name] || Style.index(arg)
      elsif arg.is_a?(::String) && arg =~ /^\e\[/ # arg is a code
        if styles = Style.code_index[arg]
          styles.first
        else
          Style.new(:code=>arg)
        end
      elsif style = Style.list[arg]
        style
      elsif HighLine.color_scheme && HighLine.color_scheme[arg]
        HighLine.color_scheme[arg]
      elsif arg.is_a?(Hash)
        Style.new(arg)
      elsif arg.to_s.downcase =~ /^rgb_([a-f0-9]{6})$/
        Style.rgb($1)
      elsif arg.to_s.downcase =~ /^on_rgb_([a-f0-9]{6})$/
        Style.rgb($1).on
      else
        raise NameError, "#{arg.inspect} is not a defined Style"
      end
    else
      name = args
      Style.list[name] || Style.new(:list=>args)
    end
  end

  class Style

    def self.index(style)
      if style.name
        @@styles ||= {}
        @@styles[style.name] = style
      end
      if !style.list
        @@code_index ||= {}
        @@code_index[style.code] ||= []
        @@code_index[style.code].reject!{|indexed_style| indexed_style.name == style.name}
        @@code_index[style.code] << style
      end
      style
    end

    def self.rgb_hex(*colors)
      colors.map do |color|
        color.is_a?(Numeric) ? '%02x'%color : color.to_s
      end.join
    end

    def self.rgb_parts(hex)
      hex.scan(/../).map{|part| part.to_i(16)}
    end

    def self.rgb(*colors)
      hex = rgb_hex(*colors)
      name = ('rgb_' + hex).to_sym
      if style = list[name]
        style
      else
        parts = rgb_parts(hex)
        new(:name=>name, :code=>"\e[38;5;#{rgb_number(parts)}m", :rgb=>parts)
      end
    end

    def self.rgb_number(*parts)
      parts = parts.flatten
      16 + parts.inject(0) {|kode, part| kode*6 + (part/256.0*6.0).floor}
    end

    def self.ansi_rgb_to_hex(ansi_number)
      raise "Invalid ANSI rgb code #{ansi_number}" unless (16..231).include?(ansi_number)
      parts = (ansi_number-16).to_s(6).rjust(3,'0').scan(/./).map{|d| (d.to_i*255.0/6.0).ceil}
      rgb_hex(*parts)
    end

    def self.list
      @@styles ||= {}
    end

    def self.code_index
      @@code_index ||= {}
    end

    def self.uncolor(string)
      string.gsub(/\e\[\d+(;\d+)*m/, '')
    end

    attr_reader :name, :list
    attr_accessor :rgb, :builtin

    # Single color/styles have :name, :code, :rgb (possibly), :builtin
    # Compound styles have :name, :list, :builtin
    def initialize(defn = {})
      @definition = defn
      @name    = defn[:name]
      @code    = defn[:code]
      @rgb     = defn[:rgb]
      @list    = defn[:list]
      @builtin = defn[:builtin]
      if @rgb
        hex = self.class.rgb_hex(@rgb)
        @name ||= 'rgb_' + hex
      elsif @list
        @name ||= @list
      end
      self.class.index self unless defn[:no_index]
    end

    def dup
      self.class.new(@definition)
    end

    def to_hash
      @definition
    end

    def color(string)
      code + string + HighLine::CLEAR
    end

    def code
      if @list
        @list.map{|element| HighLine.Style(element).code}.join
      else
        @code
      end
    end

    def red
      @rgb && @rgb[0]
    end

    def green
      @rgb && @rgb[1]
    end

    def blue
      @rgb && @rgb[2]
    end

    def variant(new_name, options={})
      raise "Cannot create a variant of a style list (#{inspect})" if @list
      new_code = options[:code] || code
      if options[:increment]
        raise "Unexpected code in #{inspect}" unless new_code =~ /^(.*?)(\d+)(.*)/
        new_code = $1 + ($2.to_i + options[:increment]).to_s + $3
      end
      new_rgb = options[:rgb] || @rgb
      self.class.new(self.to_hash.merge(:name=>new_name, :code=>new_code, :rgb=>new_rgb))
    end

    def on
      new_name = ('on_'+@name.to_s).to_sym
      self.class.list[new_name] ||= variant(new_name, :increment=>10)
    end

    def bright
      create_bright_variant(:bright)
    end

    def light
      create_bright_variant(:light)
    end

    private

    def create_bright_variant(variant_name)
      raise "Cannot create a #{name} variant of a style list (#{inspect})" if @list
      new_name = ("#{variant_name}_"+@name.to_s).to_sym
      new_rgb = @rgb == [0,0,0] ? [128, 128, 128] : @rgb.map {|color|  color==0 ? 0 : [color+128,255].min }

      find_style(new_name) or variant(new_name, :increment=>60, :rgb=>new_rgb)
    end

    def find_style(name)
      self.class.list[name]
    end
  end
end
