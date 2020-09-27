# Ruby Emoji Regex 💎

[![Gem Version](https://badge.fury.io/rb/emoji_regex.svg)](https://rubygems.org/gems/emoji_regex) [![Build Status](https://travis-ci.org/ticky/ruby-emoji-regex.svg?branch=develop)](https://travis-ci.org/ticky/ruby-emoji-regex)

A pair of Ruby regular expressions for matching Unicode Emoji symbols.

## Background

This is based upon the fantastic work from [Mathias Bynens'](https://mathiasbynens.be/) [`emoji-regex`](https://github.com/mathiasbynens/emoji-regex) Javascript package. `emoji-regex` is cleverly assembled based upon data from the Unicode Consortium.

The regular expressions provided herein are derived from that pacakge.

## Installation

```shell
gem install emoji_regex
```

## Usage

`emoji_regex` provides two regular expressions:

* `EmojiRegex::Regex` matches emoji which present as emoji by default, and those which present as emoji when combined with `U+FE0F VARIATION SELECTOR-16`.

* `EmojiRegex::Text` matches emoji which present as text by default (regardless of variation selector), as well as those which present as emoji by default.

### Emoji vs Text Presentation

`Emoji_Presentation` is a property of emoji symbols, defined in [Unicode Technical Report #51](http://unicode.org/reports/tr51/#Emoji_Properties_and_Data_Files) which controls whether symbols are intended to be rendered as emoji by default.

Generally, for emoji which re-use Unicode code points which existed before Emoji itself was introduced to Unicode, `Emoji_Presentation` is `false`.

This means they should be displayed as monochrome text characters by default, and should be combined with `U+FE0F VARIATION SELECTOR-16` to indicate emoji presentation is desired.

`EmojiRegex::Regex` follows this Unicode Consortium guidance, while `EmojiRegex::Text` matches anything that someone might possibly consider a Unicode emoji.

It's most likely that the regular expression you want is `EmojiRegex::Regex`! ☺️

### Example

```ruby
require 'emoji_regex'

text = <<TEXT
\u{231A}: ⌚ default emoji presentation character (Emoji_Presentation)
\u{2194}: ↔ default text presentation character
\u{2194}\u{FE0F}: ↔️ default text presentation character with Emoji variation selector
\u{1F469}: 👩 emoji modifier base (Emoji_Modifier_Base)
\u{1F469}\u{1F3FF}: 👩🏿 emoji modifier base followed by a modifier
TEXT

puts 'EmojiRegex::Regex'
text.scan EmojiRegex::Regex do |emoji|
  puts "Matched sequence #{emoji} — code points: #{emoji.length}"
end

puts ''

puts 'EmojiRegex::Text'
text.scan EmojiRegex::Text do |emoji|
  puts "Matched sequence #{emoji} — code points: #{emoji.length}"
end

```

Console output:

```text
EmojiRegex::Regex
Matched sequence ⌚ — code points: 1
Matched sequence ⌚ — code points: 1
Matched sequence ↔️ — code points: 2
Matched sequence ↔️ — code points: 2
Matched sequence 👩 — code points: 1
Matched sequence 👩 — code points: 1
Matched sequence 👩🏿 — code points: 2
Matched sequence 👩🏿 — code points: 2

EmojiRegex::Text
Matched sequence ⌚ — code points: 1
Matched sequence ⌚ — code points: 1
Matched sequence ↔ — code points: 1
Matched sequence ↔ — code points: 1
Matched sequence ↔️ — code points: 2
Matched sequence ↔️ — code points: 2
Matched sequence 👩 — code points: 1
Matched sequence 👩 — code points: 1
Matched sequence 👩🏿 — code points: 2
Matched sequence 👩🏿 — code points: 2
```

## Development

### Requirements

* Ruby
* [Node](https://nodejs.org) (v6 or newer)
* [Yarn](https://yarnpkg.com)

### Initial setup

To install all the Ruby and Javascript dependencies, you can run:

```bash
bin/setup
```

To update the Ruby source files based on the `emoji-regex` library:

```bash
rake regenerate
```

### Specs

A spec suite is provided, which can be run as:

```bash
rake spec
```

### Creating a release

1. Update the version in [emoji_regex.gemspec](emoji_regex.gemspec)
1. `rake release`
