require 'test/unit'
require 'highline/import'
require 'highline/simulate'

class SimulatorTest < Test::Unit::TestCase
  def setup
    input     = StringIO.new
    output    = StringIO.new
    $terminal = HighLine.new(input, output)
  end

  def test_simulator
    HighLine::Simulate.with('Bugs Bunny', '18') do
      name = ask('What is your name?')

      assert_equal 'Bugs Bunny', name

      age = ask('What is your age?')

      assert_equal '18', age
    end
  end

  def test_simulate_with_echo_and_frozen_strings
    HighLine::Simulate.with('the password'.freeze) do
      password = ask('What is your password?') do |q|
        q.echo = '*'
      end

      assert_equal 'the password', password
    end
  end
end