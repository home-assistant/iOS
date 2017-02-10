fastlane documentation
================
# Installation
```
sudo gem install fastlane
```
# Available Actions
## iOS
### ios certs
```
fastlane ios certs
```
Fetches the provisioning profiles so you can build locally and deploy to your device
### ios ci
```
fastlane ios ci
```
Runs all the unit tests

Submits a new Beta Build to Fabric

Submits a new Beta Build to Apple TestFlight
### ios bump
```
fastlane ios bump
```
Bump build number
### ios release
```
fastlane ios release
```

### ios itc
```
fastlane ios itc
```
Submit a new Beta Build to Apple TestFlight

This will also make sure the profile is up to date
### ios fabric
```
fastlane ios fabric
```
Submit a new Beta Build to Fabric

This will also make sure the profile is up to date

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [https://fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [GitHub](https://github.com/fastlane/fastlane/tree/master/fastlane).
