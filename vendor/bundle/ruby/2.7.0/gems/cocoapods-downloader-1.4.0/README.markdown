# Downloader

A small library for downloading files from remotes in a folder.

[![Build Status](https://img.shields.io/travis/CocoaPods/cocoapods-downloader/master.svg?style=flat)](https://travis-ci.org/CocoaPods/cocoapods-downloader)
[![Coverage](https://img.shields.io/codeclimate/coverage/github/CocoaPods/cocoapods-downloader.svg?style=flat)](https://codeclimate.com/github/CocoaPods/cocoapods-downloader)
[![Code Climate](https://img.shields.io/codeclimate/github/CocoaPods/cocoapods-downloader.svg?style=flat)](https://codeclimate.com/github/CocoaPods/cocoapods-downloader)

## Install

```
$ [sudo] gem install cocoapods-downloader
```

## Usage

```ruby
require 'cocoapods-downloader'

target_path = './Downloads/MyDownload'
options = { :git => 'example.com' }
options = Pod::Downloader.preprocess_options(options)
downloader = Pod::Downloader.for_target(target_path, options)
downloader.cache_root = '~/Library/Caches/APPNAME'
downloader.max_cache_size = 500
downloader.download
downloader.checkout_options #=> { :git => 'example.com', :commit => 'd7f410490dabf7a6bde665ba22da102c3acf1bd9' }
```

The downloader class supports the following option keys:

- git: commit, tag, branch, submodules
- svn: revision, tag, folder, externals
- hg: revision, tag, branch
- http: type, flatten
- scp: type, flatten
- bzr: revision, tag

The downloader also provides hooks which allow to customize its output or the way in which the commands are executed

```ruby
require 'cocoapods-downloader'

module Pod
  module Downloader
    class Base

      override_api do
        def self.execute_command(executable, command, raise_on_failure = false)
          puts "Will download"
          super
        end

        def self.ui_action(ui_message)
          puts ui_message.green
          yield
        end
      end

    end
  end
end
```

## Extraction

This gem was extracted from [CocoaPods](https://github.com/CocoaPods/CocoaPods). Refer to also that repository for the history and the contributors.

## Collaborate

All CocoaPods development happens on GitHub, there is a repository for [CocoaPods](https://github.com/CocoaPods/CocoaPods) and one for the [CocoaPods specs](https://github.com/CocoaPods/Specs). Contributing patches or Pods is really easy and gratifying and for a lot of people is their first time.

Follow [@CocoaPods](http://twitter.com/CocoaPods) to get up to date information about what's going on in the CocoaPods world.

## License

This gem and CocoaPods are available under the MIT license.
