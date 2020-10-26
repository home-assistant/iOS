Home Assistant for Apple Platforms
=================

[![TestFlight Beta invite](https://img.shields.io/badge/TestFlight-Beta-blue.svg)](https://www.home-assistant.io/ios/beta/)
[![Download on the App Store](https://img.shields.io/itunes/v/1099568401.svg)](https://itunes.apple.com/app/home-assistant-open-source-home-automation/id1099568401)
[![GitHub issues](https://img.shields.io/github/issues/home-assistant/iOS.svg?style=flat)](https://github.com/home-assistant/iOS/issues)
[![License Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-green.svg?style=flat)](https://github.com/home-assistant/iOS/blob/master/LICENSE)

## Getting Started

Home Assistant uses Bundler, Cocoapods and Swift Package Manager to manage build dependencies. You'll need Xcode 12.1 (or later) which you can download from the [App Store](https://developer.apple.com/download/). You can get this running using the following commands:

```bash
git clone https://github.com/home-assistant/iOS.git
cd iOS
[sudo] gem install bundler
bundle install
bundle exec pod install --repo-update
```

Once this completes, you can launch  `HomeAssistant.xcworkspace` and run the `Debug` target onto your simulator or iOS device.

## Code Signing

Although the app is set up to use Automatic provisioning for Debug builds, you'll need to customize a few of the options. This is because the app makes heavy use of entitlements that require code signing, even for simulator builds.

Edit the file `Configuration/HomeAssistant.overrides.xcconfig` (which will not exist by default and is ignored by git) and add the following:

```bash
DEVELOPMENT_TEAM = YourTeamID
BUNDLE_ID_PREFIX = some.bundle.prefix
```

Xcode should generate provisioning profiles in your Team ID and our configuration will disable features your team doesn't have like Critical Alerts. You can find your Team ID on Apple's [developer portal](https://developer.apple.com/account).

## Code style

SwiftLint runs as part of Pull Request checks and will run automatically when building the project.

## Continuous Integration

We are using [Github Actions](https://github.com/home-assistant/iOS/actions) alongside [Fastlane](https://fastlane.tools/) to perform continuous integration both by unit testing and deploying to [App Store Connect](https://appstoreconnect.apple.com) later on.

### Environment variables

To make sure Fabric and App Store Connect can deploy, make sure you have them set to something similar to the following environment variables. **The values are only examples!**.

**Note:** For ENV variables to work in Xcode you to set `$ defaults write com.apple.dt.Xcode UseSanitizedBuildSystemEnvironment -bool NO` and launch Xcode from the terminal. [Apple Developer Forums](https://forums.developer.apple.com/thread/8451)

#### Signing

- `HOMEASSISTANT_CERTIFICATE_KEY`: The Certificate key used in [Match](https://github.com/fastlane/fastlane/tree/master/match)
- `HOMEASSISTANT_CERTIFICATE_USER`: The username for the git being where Match is saving the Certificates.
- `HOMEASSISTANT_CERTIFICATE_TOKEN`: The access token for the git being where Match is saving the Certificates.
- `HOMEASSISTANT_CERTIFICATE_GIT`: The address or the git being where Match is saving the Certificates. (e.g. https://gitlab.com/username/Certificates)

#### App Store Connect deployment

- `HOMEASSISTANT_TEAM_ID`: Team ID from [App Store Connect Membership](https://developer.apple.com/account/#/membership)
- `HOMEASSISTANT_APP_STORE_CONNECT_TEAM_ID`: Team ID from [App Store Connect](https://appstoreconnect.apple.com/). (`$ pilot list` to check the number)
- `HOMEASSISTANT_APPLE_ID`: Your Apple ID (e.g. john@apple.com)

### Deployment

Although all the deployment is done through Github Actions, you can do it manually through [Fastlane](https://github.com/home-assistant/iOS/blob/master/fastlane/README.md):

### Deployment to App Store Connect

```bash
bundle exec fastlane asc
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## LICENSE

Apache-2.0

## Credits

The format and some content of this README.md comes from the [SwipeIt](https://github.com/ivanbruel/SwipeIt) project.
