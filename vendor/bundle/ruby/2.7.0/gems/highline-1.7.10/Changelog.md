## Change Log

Below is a complete listing of changes for each revision of HighLine.

### 1.7.10 / 2017-11-23
* Add gemspec to Gemfile. Address #223. (@abinoam)

### 1.7.9 / 2017-05-08
* Fix frozen string issue on HighLine::Simulate. (Ivan Giuliani (@ivgiuliani), PR #210)

### 1.7.8 / 2015-10-09
* Fix some issues when paginating. (Nick Carboni (@carbonin) and Abinoam P. Marques Jr. (@abinoam), #168, PRs #169 #170)

### 1.7.7 / 2015-09-22
* Make HighLine::Question coerce its question argument into a String. (@97-109-107 and Abinoam P. Marques Jr. (@abinoam), #159, PR #160)

### 1.7.6 / 2015-09-17
* Fix a typo in a var name affecting solaris. (Danek Duvall (@dhduvall) and Abinoam P. Marques Jr. (@abinoam), #155, PR #156)

### 1.7.5 / 2015-09-14
* Support jruby9k for system extensions (Michael (@mmmries), PR #153)

### 1.7.4 / 2015-06-16
* Workaround on #55 for stty

### 1.7.3 / 2015-06-29
* Add HighLine::Simulator tests (Bala Paranj (@bparanj) and Abinoam Marques Jr. (@abinoam), #142, PR #143)

### 1.7.2 / 2015-04-19

#### Bug fixes
* Fix #138 (a regression of #131). PR #139.

### 1.7.1 / 2015-02-24

#### Enhancements
* Add travis CI configuration (Eli Young (@elyscape), #130)
* Add Rubinius to Build Matrix with Allowed Failure (Brandon Fish
(bjfish), #132)
* Make some adjustments on tests (Abinoam Marques Jr., #133, #134)
* Drop support for Ruby 1.8 (Abinoam Marques Jr., #134)

#### Bug fixes
* Fix IO.console.winsize returning reversed column and line values (Fission Xuiptz (@fissionxuiptz)), #131)

### 1.7.0 / 2015-02-18

#### Bug fixes
* Fix correct encoding of statements to output encoding (Dāvis (davispuh), #110)
* Fix character echoing when echo is false and multibyte character is typed (Abinoam Marques Jr., #117 #118)
* Fix backspace support on Cyrillic (Abinoam Marques Jr., #115 #118)
* Fix returning wrong encoding when echo is false (Abinoam Marques Jr., #116 #118)
* Fix Question #limit and #realine incompatibilities (Abinoam Marques Jr. #113 #120)
* Fix/improve string coercion on #say (Abinoam Marques Jr., #98 #122)
* Fix #terminal_size returning nil in some terminals (Abinoam Marques Jr., #85 #123)

#### Enhancements
* Improve #format_statement String coercion (Michael Bishop
(michaeljbishop), #104)
* Update homepage url on gemspec (Rubyforge->GitHub) (Edward Anderson
(nilbus), #107)
* Update COPYING file (Vít Ondruch (voxik), #109)
* Improve multi-byte encoding support (Abinoam Marques Jr., #115 #116 #117 #118)
* Make :grey -> :gray and :light -> :bright aliases (Abinoam Marques Jr., #114 #119)
* Return the default object (as it is) when no answer given (Abinoam Marques Jr., #112 #121)
* Added test for Yaml serialization of HighLine::String (Abinoam Marques Jr., #69 #124)
* Make improvements on Changelog and Rakefile (Abinoam Marques Jr., #126 #127 #128)

### 1.6.21

* Improved Windows integration (by Ronie Henrich).
* Clarified menu choice error messages (by Keith Bennett).

### 1.6.20

* Fixed a bug with FFI::NCurses integration (by agentdave).
* Improved StringExtensions performance (by John Leach).
* Various JRuby fixes (by presidentbeef).

### 1.6.19

* Fixed `terminal_size()` with jline2 (by presidentbeef).

### 1.6.18

* Fixed a long supported interface that was accidentally broken with a recent change (by Rubem Nakamura Carneiro).

### 1.6.17

* Added encoding support to menus (by David Lyons).
* Some minor fixes to SystemExtensions (by whiteleaf and presidentbeef).

### 1.6.16

* Added the new indention feature (by davispuh).
* Separated auto-completion from the answer type (by davispuh).
* Improved JRuby support (by rsutphin).
* General code clean up (by stomar).
* Made HighLine#say() a little smarter with regard to color escapes (by Kenneth Murphy).

### 1.6.15

* Added support for nil arguments in lists (by Eric Saxby).
* Fixed HighLine's termios integration (by Jens Wille).

### 1.6.14

* Added JRuby 1.7 support (by Mina Nagy).
* Take into account color escape sequences when wrapping text (by Mark J.
  Titorenko).

### 1.6.13

* Removed unneeded Shebang lines (by Scott Gonyea).
* Protect the String passed to Question.new from modification (by michael).
* Added a retype-to-verify setting (by michael).

### 1.6.12

* Silenced warnings (by James McEwan).

### 1.6.11

* Fixed a bad test.  (Fix by Diego Elio Pettenò.)

### 1.6.10

* Fixed a regression that prevented asking for String arguments (by Jeffery
  Sman.)
* Fixed a testing incompatibility (by Hans de Graaff.)

### 1.6.9

* The new list modes now properly ignore escapes when sizing.
* Added a project gemspec file.
* Fixed a bug that prevented the use of termios (by tomdz).
* Switch to JLine to provide better echo support on JRuby (by tomdz).

### 1.6.8

* Fix missing <tt>ERASE_CHAR</tt> reference (by Aaron Gifford).

### 1.6.7

* Fixed bug introduced in 1.6.6 attempted fix (by Aaron Gifford).

### 1.6.6

* Fixed old style references causing <tt>HighLine::String</tt> errors (by Aaron Gifford).

### 1.6.5

* HighLine#list() now correctly handles empty lists (fix by Lachlan Dowding).
* HighLine#list() now supports <tt>:uneven_columns_across</tt> and
  <tt>:uneven_columns_down</tt> modes.

### 1.6.4

* Add introspection methods to color_scheme: definition, keys, to_hash.
* Add tests for new methods.

### 1.6.3

* Add color NONE.
* Add RGB color capability.
* Made 'color' available as a class or instance method of HighLine, for
  instance: HighLine.color("foo", :blue)) or highline_obj.color("foo", :blue)
  are now both possible and equivalent.
* Add HighLine::String class with convenience methods: #color (alias
  #foreground), #on (alias #background), colors, and styles. See
  lib/string_extensions.rb.
* Add (optional) ability to extend String with the same convenience methods from
  HighLine::String, using Highline.colorize_strings.

### 1.6.2

* Correctly handle STDIN being closed before we receive any data (fix by
  mleinart).
* Try if msvcrt, if we can't load crtdll on Windows (fix by pepijnve).
* A fix for nil_on_handled not running the action (reported by Andrew Davey).

### 1.6.1

* Fixed raw_no_echo_mode so that it uses stty -icanon rather than cbreak
  as cbreak does not appear to be the posixly correct argument. It fails
  on Solaris if cbreak is used.
* Fixed an issue that kept Menu from showing the correct choices for
  disambiguation.
* Removed a circular require that kept Ruby 1.9.2 from loading HighLine.
* Fixed a bug that caused infinite looping when wrapping text without spaces.
* Fixed it so that :auto paging accounts for the two lines it adds.
* On JRuby, improved error message about ffi-ncurses.  Before 1.5.3,
  HighLine was silently swallowing error messages when ffi-ncurses gem
  was installed without ncurses present on the system.
* Reverted Aaron Simmons's patch to allow redirecting STDIN on Windows.  This
  is the only way we could find to restore HighLine's character reading to
  working order.

### 1.5.2

* Added support for using the ffi-ncurses gem which is supported in JRuby.
* Added gem build instructions.

### 1.5.1

* Fixed the long standing echo true bug.
  (reported by Lauri Tuominen)
* Improved Windows API calls to support the redirection of STDIN.
  (patch by Aaron Simmons)
* Updated gem specification to avoid a deprecated call.
* Made a minor documentation clarification about character mode support.
* Worked around some API changes in Ruby's standard library in Ruby 1.9.
  (patch by Jake Benilov)

### 1.5.0

* Fixed a bug that would prevent Readline from showing all completions.
  (reported by Yaohan Chen)
* Added the ability to pass a block to HighLine#agree().
  (patch by Yaohan Chen)

### 1.4.0

* Made the code grabbing terminal size a little more cross-platform by
  adding support for Solaris.  (patch by Ronald Braswell and Coey Minear)

### 1.2.9

* Additional work on the backspacing issue. (patch by Jeremy Hinegardner)
* Fixed Readline prompt bug. (patch by Jeremy Hinegardner)

### 1.2.8

* Fixed backspacing past the prompt and interrupting a prompt bugs.
  (patch by Jeremy Hinegardner)

### 1.2.7

* Fixed the stty indent bug.
* Fixed the echo backspace bug.
* Added HighLine::track_eof=() setting to work are threaded eof?() calls.

### 1.2.6

Patch by Jeremy Hinegardner:

* Added ColorScheme support.
* Added HighLine::Question.overwrite mode.
* Various documentation fixes.

### 1.2.5

* Really fixed the bug I tried to fix in 1.2.4.

### 1.2.4

* Fixed a crash causing bug when using menus, reported by Patrick Hof.

### 1.2.3

* Treat Cygwin like a Posix OS, instead of a native Windows environment.

### 1.2.2

* Minor documentation corrections.
* Applied Thomas Werschleiln's patch to fix termio buffering on Solaris.
* Applied Justin Bailey's patch to allow canceling paged output.
* Fixed a documentation bug in the description of character case settings.
* Added a notice about termios in HighLine::Question#echo.
* Finally working around the infamous "fast typing" bug

### 1.2.1

* Applied Justin Bailey's fix for the page_print() infinite loop bug.
* Made a SystemExtensions module to expose OS level functionality other
  libraries may want to access.
* Publicly exposed the get_character() method, per user requests.
* Added terminal_size(), output_cols(), and output_rows() methods.
* Added :auto setting for warp_at=() and page_at=().

### 1.2.0

* Improved RubyForge and gem spec project descriptions.
* Added basic examples to README.
* Added a VERSION constant.
* Added support for hidden menu commands.
* Added Object.or_ask() when using highline/import.

### 1.0.4

* Moved the HighLine project to Subversion.
* HighLine's color escapes can now be disabled.
* Fixed EOF bug introduced in the last release.
* Updated HighLine web page.
* Moved to a forked development/stable version numbering.

### 1.0.2

* Removed old and broken help tests.
* Fixed test case typo found by David A. Black.
* Added ERb escapes processing to lists, for coloring list items.  Color escapes
  do not add to list element size.
* HighLine now throws EOFError when input is exhausted.

### 1.0.1

* Minor bug fix:  Moved help initialization to before response building, so help
  would show up in the default responses.

### 1.0.0

* Fixed documentation typo pointed out by Gavin Kistner.
* Added <tt>gather = ...</tt> option to question for fetching entire Arrays or
  Hashes filled with answers.  You can set +gather+ to a count of answers to
  collect, a String or Regexp matching the end of input, or a Hash where each
  key can be used in a new question.
* Added File support to HighLine.ask().  You can specify a _directory_ and a
  _glob_ pattern that combine into a list of file choices the user can select
  from.  You can choose to receive the user's answer as an open filehandle or as
  a Pathname object.
* Added Readline support for history and editing.
* Added tab completion for menu  and file selection selection (requires
  Readline).
* Added an optional character limit for input.
* Added a complete help system to HighLine's shell menu creation tools.

### 0.6.1

* Removed termios dependancy in gem, to fix Windows' install.

### 0.6.0

* Implemented HighLine.choose() for menu handling.
  * Provided shortcut <tt>choose(item1, item2, ...)</tt> for simple menus.
  * Allowed Ruby code to be attached to each menu item, to create a complete
    menu solution.
  * Provided for total customization of the menu layout.
  * Allowed for menu selection by index, name or both.
  * Added a _shell_ mode to allow menu selection with additional details
    following the name.
* Added a list() utility method that can be invoked just like color().  It can
  layout Arrays for you in any output in the modes <tt>:columns_across</tt>,
  <tt>:columns_down</tt>, <tt>:inline</tt> and <tt>:rows</tt>
* Added support for <tt>echo = "*"</tt> style settings.  User code can now
  choose the echo character this way.
* Modified HighLine to user the "termios" library for character input, if
  available.  Will return to old behavior (using "stty"), if "termios" cannot be
  loaded.
* Improved "stty" state restoring code.
* Fixed "stty" code to handle interrupt signals.
* Improved the default auto-complete error message and exposed this message
  through the +responses+ interface as <tt>:no_completion</tt>.

### 0.5.0

* Implemented <tt>echo = false</tt> for HighLine::Question objects, primarily to
  make fetching passwords trivial.
* Fixed an auto-complete bug that could cause a crash when the user gave an
  answer that didn't complete to any valid choice.
* Implemented +case+ for HighLine::Question objects to provide character case
  conversions on given answers.  Can be set to <tt>:up</tt>, <tt>:down</tt>, or
  <tt>:capitalize</tt>.
* Exposed <tt>@answer</tt> to the response system, to allow response that are
  aware of incorrect input.
* Implemented +confirm+ for HighLine::Question objects to allow for verification
  for sensitive user choices.  If set to +true+, user will have to answer an
  "Are you sure?  " question.  Can also be set to the question to confirm with
  the user.

### 0.4.0

* Added <tt>@wrap_at</tt> and <tt>@page_at</tt> settings and accessors to
  HighLine, to control text flow.
* Implemented line wrapping with adjustable limit.
* Implemented paged printing with adjustable limit.

### 0.3.0

* Added support for installing with setup.rb.
* All output is now treated as an ERb sequence, allowing Ruby code to be
  embedded in output strings.
* Added support for ANSI color sequences in say().  (And everything else
  by extension.)
* Added whitespace handling for answers.  Can be set to <tt>:strip</tt>,
  <tt>:chomp</tt>, <tt>:collapse</tt>, <tt>:strip_and_collapse</tt>,
  <tt>:chomp_and_collapse</tt>, <tt>:remove</tt>, or <tt>:none</tt>.
* Exposed question details to ERb completion through @question, to allow for
  intelligent responses.
* Simplified HighLine internals using @question.
* Added support for fetching single character input either with getc() or
  HighLine's own cross-platform terminal input routine.
* Improved type conversion to handle user defined classes.

### 0.2.0

* Added Unit Tests to cover an already fixed output bug in the future.
* Added Rakefile and setup test action (default).
* Renamed HighLine::Answer to HighLine::Question to better illustrate its role.
* Renamed fetch_line() to get_response() to better define its goal.
* Simplified explain_error in terms of the Question object.
* Renamed accept?() to in_range?() to better define purpose.
* Reworked valid?() into valid_answer?() to better fit Question object.
* Reworked <tt>@member</tt> into <tt>@in</tt>, to make it easier to remember and
  switched implementation to include?().
* Added range checks for @above and @below.
* Fixed the bug causing ask() to swallow NoMethodErrors.
* Rolled ask_on_error() into responses.
* Redirected imports to Kernel from Object.
* Added support for <tt>validate = lambda { ... }</tt>.
* Added default answer support.
* Fixed bug that caused ask() to die with an empty question.
* Added complete documentation.
* Improve the implemetation of agree() to be the intended "yes" or "no" only
  question.
* Added Rake tasks for documentation and packaging.
* Moved project to RubyForge.

### 0.1.0

* Initial release as the solution to
  {Ruby Quiz #29}[http://www.rubyquiz.com/quiz29.html].
