# clean_testflight_testers plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-clean_testflight_testers)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-clean_testflight_testers`, add it to your project by running:

```bash
fastlane add_plugin clean_testflight_testers
```

## About clean_testflight_testers

![screenshot.png](screenshot.png)

> Automatically remove TestFlight testers that are not actually testing your app

Just add the following to your `fastlane/Fastfile`

```ruby
# Default setup
lane :clean do
  clean_testflight_testers
end

# This won't delete out inactive testers, but just print them
lane :clean do
  clean_testflight_testers(dry_run: true)
end

# Specify a custom number for what's "inactive"
lane :clean do
  clean_testflight_testers(days_of_inactivity: 120) # 120 days, so about 4 months
end

# Provide custom app identifier / username
lane :clean do
  clean_testflight_testers(username: "apple@krausefx.com", app_identifier: "best.lane"")
end
```

The plugin will remove all testers that either:

- Received a TestFlight email, but didn't accept the invite within the last 30 days
- Installed the app within the last 30 days, but didn't launch it once

Unfortunately the iTunes Connect UI/API doesn't expose the timestamp of the last user session, so we can't really detect the last time someone used the app. The above rules will still help you, remove a big part of inactive testers. 

This plugin could also be smarter, and compare the time stamp of the last build, and compare it with the latest tester activity, feel free to submit a PR for this feature 👍

## Issues and Feedback

Make sure to update to the latest _fastlane_.

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
