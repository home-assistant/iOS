fastlane documentation
================
# Installation
```
sudo gem install fastlane
```
# Available Actions
## iOS
### ios test
```
fastlane ios test
```
Runs all the tests
### ios xcode
```
fastlane ios xcode
```
Installs FixCode which disables the "Fix Issue" button in Xcode
### ios certs
```
fastlane ios certs
```
Fetches the provisioning profiles so you can build locally and deploy to your device
### ios push
```
fastlane ios push
```
Creates a new push certificate, ready to be uploaded to SNS
### ios beta
```
fastlane ios beta
```
Submit a new Beta Build to Apple TestFlight

This will also make sure the profile is up to date
### ios testflight
```
fastlane ios testflight
```

### ios appstore
```
fastlane ios appstore
```
Deploy a new version to the App Store

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [https://fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [GitHub](https://github.com/fastlane/fastlane/tree/master/fastlane).
