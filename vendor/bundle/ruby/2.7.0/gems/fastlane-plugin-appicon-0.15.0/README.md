# appicon plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-appicon)

![Demo image](demo.png)

## Getting Started

This project is a [fastlane](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-appicon`, add it to your project by running:

```bash
fastlane add_plugin appicon
```

Please note that this plugin uses the GraphicsMagick library. If you do not have it, you can install it via Homebrew:

```
brew install graphicsmagick
```

## About appicon

Generate required icon sizes and iconset from a master application icon.

Since many apps use a single 1024x1024 icon to produce all the required sizes from, why not automate the process and save lots of time?

## Example

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.

Just specify the source image using the `appicon_image_file`. Optionally specify the devices using `appicon_devices` and the destination path using `appicon_path`.

We recommend storing the full-size picture at `fastlane/metadata/app_icon.png` so it can be picked up by _deliver_, as well as this plugin

```ruby
lane :basic do
  appicon(
    appicon_devices: [:ipad, :iphone, :ios_marketing],
    appicon_path: "MajorKey/Assets.xcassets"
  )
end

lane :test1 do
  appicon(appicon_image_file: 'spec/fixtures/Themoji.png',
             appicon_devices: [:ipad, :iphone, :ios_marketing])
end


lane :test2 do
  appicon(appicon_image_file: 'spec/fixtures/Themoji.png',
             appicon_devices: [:ipad, :iphone, :ios_marketing, :watch, :watch_marketing])
end

lane :test3 do
  # `appicon_image_file` defaults to "fastlane/metadata/app_icon.png"
  appicon(
    appicon_devices: [:iphone],
    appicon_path: 'wwdcfamily/Images.xcassets' # output path
  )
end

lane :splash_screen do
  appicon(
    appicon_image_file: 'spec/fixtures/splash_screen.png',
    appicon_devices: [:universal],
    appicon_path: "ios/App/App/Assets.xcassets",
    appicon_name: 'Splash.imageset'
  )
end

# or

lane :android do
  android_appicon(
    appicon_image_file: 'spec/fixtures/Themoji.png',
    appicon_icon_types: [:launcher],
    appicon_path: 'app/res/mipmap'
  )
  android_appicon(
    appicon_image_file: 'spec/fixtures/ThemojiNotification.png',
    appicon_icon_types: [:notification],
    appicon_path: 'app/res/drawable',
    appicon_filename: 'ic_notification',
    generate_rounded: true
  )
  android_appicon(
    appicon_image_file: 'spec/fixtures/splash_base_image.png',
    appicon_icon_types: [:splash_port, :splash_land],
    appicon_path: 'app/res/drawable',
    appicon_filename: 'splash'
  )
end
```

## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://github.com/fastlane/fastlane/blob/master/fastlane/docs/PluginsTroubleshooting.md) doc in the main `fastlane` repo.

## Using `fastlane` Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Plugins.md).

## About `fastlane`

`fastlane` is the easiest way to automate building and releasing your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
