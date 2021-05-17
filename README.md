Home Assistant for Apple Platforms
=================

[![TestFlight Beta invite](https://img.shields.io/badge/TestFlight-Beta-blue.svg)](https://www.home-assistant.io/ios/beta/)
[![Download on the App Store](https://img.shields.io/itunes/v/1099568401.svg)](https://itunes.apple.com/app/home-assistant-open-source-home-automation/id1099568401)
[![GitHub issues](https://img.shields.io/github/issues/home-assistant/iOS.svg?style=flat)](https://github.com/home-assistant/iOS/issues)
[![License Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-green.svg?style=flat)](https://github.com/home-assistant/iOS/blob/master/LICENSE)

## Getting Started

Home Assistant uses Bundler, Homebrew and Cocoapods to manage build dependencies. You'll need Xcode 12.3 (or later) which you can download from the [App Store](https://developer.apple.com/download/). You can get the app running using the following commands:

```bash
git clone https://github.com/home-assistant/iOS.git
cd iOS
# if you don't have bundler already, [sudo] gem install bundler
# if you don't have homebrew already, install from https://brew.sh
brew bundle
bundle install
bundle exec pod install --repo-update
```

Once this completes, you can launch  `HomeAssistant.xcworkspace` and run the `App-Debug` scheme onto your simulator or iOS device.

## Code Signing

Although the app is set up to use Automatic provisioning for Debug builds, you'll need to customize a few of the options. This is because the app makes heavy use of entitlements that require code signing, even for simulator builds.

Edit the file `Configuration/HomeAssistant.overrides.xcconfig` (which will not exist by default and is ignored by git) and add the following:

```bash
DEVELOPMENT_TEAM = YourTeamID
BUNDLE_ID_PREFIX = some.bundle.prefix
```

Xcode should generate provisioning profiles in your Team ID and our configuration will disable features your team doesn't have like Critical Alerts. You can find your Team ID on Apple's [developer portal](https://developer.apple.com/account); it looks something like `ABCDEFG123`.

## Watch Development

To develop any of the Watch Extensions, you must remove the `Launcher` dependency from the App target. It's not clear what's breaking the project that necessitates this, but otherwise it will attempt to launch that target in the Watch Simulator or fail to launch and just hang.

## Code style

Linters run as part of Pull Request checks. Additionally, some linting requirements can be autocorrected.

```bash
# checks for linting problems, doesn't fix
bundle exec fastlane lint
# checks for linting problems and fixes them
bundle exec fastlane autocorrect
```

In the Xcode project, the autocorrectable linters will not modify your source code but will provide warnings. This project uses several linters:

- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
- [SwiftLint](https://github.com/realm/swiftlint) (for things SwiftFormat doesn't automate)
- [Rubocop](https://rubocop.org) (largely for Fastlane)
- [YamlLint](https://yamllint.readthedocs.io/en/stable/index.html) (largely for GitHub Actions)

## Continuous Integration

We use [Github Actions](https://github.com/home-assistant/iOS/actions) alongside [Fastlane](https://fastlane.tools/) to perform continuous integration both by unit testing and deploying to [App Store Connect](https://appstoreconnect.apple.com). Mac Developer ID builds are available as an artifact on every build of master.

### Environment variables

Fastlane scripts read from the environment or `.env` file for configuration like team IDs. See [`.env.sample`](https://github.com/home-assistant/iOS/blob/master/.env.sample) for available values.

### Deployment

Although all the deployment is done through Github Actions, you can do it manually through [Fastlane](https://github.com/home-assistant/iOS/blob/master/fastlane/README.md):

### Deployment to App Store Connect

```bash
# creates the builds and uploads to the app store
# each save their artifacts to build/
bundle exec fastlane mac build
bundle exec fastlane ios build
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## LICENSE

Apache-2.0

## Credits

The format and some content of this README.md comes from the [SwipeIt](https://github.com/ivanbruel/SwipeIt) project.
