require 'spec_helper'

describe Commander::HelpFormatter::TerminalCompact do
  include Commander::Methods

  before :each do
    mock_terminal
  end

  describe 'global help' do
    before :each do
      new_command_runner 'help' do
        program :help_formatter, :compact
        command :'install gem' do |c|
          c.syntax = 'foo install gem [options]'
          c.summary = 'Install some gem'
        end
      end.run!
      @global_help = @output.string
    end

    describe 'should display' do
      it 'the command name' do
        expect(@global_help).to include('install gem')
      end

      it 'the summary' do
        expect(@global_help).to include('Install some gem')
      end

      it 'one space between command name and summary' do
        expect(@global_help).to include('install gem Install some gem')
      end
    end

    describe 'should not display' do
      it 'the commands label with description for default_command' do
        expect(@global_help).not_to include('Commands: (* default)')
      end
    end
  end

  describe 'global help with default_command' do
    describe 'with command option' do
      describe 'default_command is before command' do
        before :each do
          new_command_runner 'help' do
            program :help_formatter, :compact
            default_command :'install gem'
            command :'install gem' do |c|
              c.syntax = 'foo install gem [options]'
              c.summary = 'Install some gem'
              c.option('--testing-command', 'Testing command')
              c.option('--testing-command-second', 'Testing command second')
            end
          end.run!
          @global_help = @output.string
        end

        describe 'should display' do
          it 'the commands label with description for default_command' do
            expect(@global_help).to include('Commands: (* default)')
          end

          it 'the command name' do
            expect(@global_help).to include('install gem')
          end

          it 'the summary with marked as default_command' do
            expect(@global_help).to include('* Install some gem')
          end

          it 'the options label' do
            expect(@global_help).to include('Options for install gem')
          end

          it 'the command options' do
            expect(@global_help).to include('--testing-command')
            expect(@global_help).to include('--testing-command-second')
          end
        end
      end

      describe 'default_command is after command' do
        before :each do
          new_command_runner 'help' do
            program :help_formatter, :compact
            command :'install gem' do |c|
              c.syntax = 'foo install gem [options]'
              c.summary = 'Install some gem'
              c.option('--testing-command', 'Testing command')
              c.option('--testing-command-second', 'Testing command second')
            end
            default_command :'install gem'
          end.run!
          @global_help = @output.string
        end

        describe 'should display' do
          it 'the commands label with description for default_command' do
            expect(@global_help).to include('Commands: (* default)')
          end

          it 'the command name' do
            expect(@global_help).to include('install gem')
          end

          it 'the summary with marked as default_command' do
            expect(@global_help).to include('* Install some gem')
          end

          it 'the options label' do
            expect(@global_help).to include('Options for install gem')
          end

          it 'the command options' do
            expect(@global_help).to include('--testing-command')
            expect(@global_help).to include('--testing-command-second')
          end
        end
      end
    end

    describe 'without command option' do
      before :each do
        new_command_runner 'help' do
          program :help_formatter, :compact
          command :'install gem' do |c|
            c.syntax = 'foo install gem [options]'
            c.summary = 'Install some gem'
          end
          default_command :'install gem'
        end.run!
        @global_help = @output.string
      end

      describe 'should display' do
        it 'the commands label with description for default_command' do
          expect(@global_help).to include('Commands: (* default)')
        end

        it 'the command name' do
          expect(@global_help).to include('install gem')
        end

        it 'the summary' do
          expect(@global_help).to include('* Install some gem')
        end
      end

      describe 'should not display' do
        it 'the options label' do
          expect(@global_help).not_to include('Options for install gem')
        end
      end
    end
  end

  describe 'command help' do
    before :each do
      new_command_runner 'help', 'install', 'gem' do
        program :help_formatter, :compact
        command :'install gem' do |c|
          c.syntax = 'foo install gem [options]'
          c.summary = 'Install some gem'
          c.description = 'Install some gem, blah blah blah'
          c.example 'one', 'two'
          c.example 'three', 'four'
        end
      end.run!
      @command_help = @output.string
    end

    describe 'should display' do
      it 'the command name' do
        expect(@command_help).to include('install gem')
      end

      it 'the description' do
        expect(@command_help).to include('Install some gem, blah blah blah')
      end

      it 'all examples' do
        expect(@command_help).to include('# one')
        expect(@command_help).to include('two')
        expect(@command_help).to include('# three')
        expect(@command_help).to include('four')
      end

      it 'the syntax' do
        expect(@command_help).to include('foo install gem [options]')
      end
    end
  end
end
