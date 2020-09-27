# xcconfig plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-xcconfig)[![Build Status](https://travis-ci.org/sovcharenko/fastlane-plugin-xcconfig.svg?branch=master)](https://travis-ci.org/sovcharenko/fastlane-plugin-xcconfig)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-xcconfig`, add it to your project by running:

```bash
fastlane add_plugin xcconfig
```

## About xcconfig
Adds 3 actions to fastlane to read and update xcconfig files.


## Example

```ruby
lane :test do

  # Read PRODUCT_BUNDLE_IDENTIFIER value from Configs/Release.xcconfig
  bundle_id = get_xcconfig_value(
    path: 'fastlane/Configs/Release.xcconfig',
    name: 'PRODUCT_BUNDLE_IDENTIFIER'
  )

  # Update PRODUCT_NAME value to 'Updated App' in Configs/Test.xcconfig
  # Will fail if PRODUCT_NAME doesn't exist in Configs/Test.xcconfig
  update_xcconfig_value(
    path: 'fastlane/Test.xcconfig',
    name: 'PRODUCT_NAME',
    value: 'Updated App'
  )

  # Sets PRODUCT_BUNDLE_IDENTIFIER value to 'com.sovcharenko.App-beta' in Configs/Release.xcconfig
  # PRODUCT_BUNDLE_IDENTIFIER will be added if it doesn't exist
  set_xcconfig_value(
    path: 'fastlane/Configs/Release.xcconfig',
    name: 'PRODUCT_BUNDLE_IDENTIFIER',
    value: 'com.sovcharenko.App-beta'
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

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
