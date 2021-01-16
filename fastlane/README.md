fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew install fastlane`

# Available Actions
## iOS
### ios clean_all_testers
```
fastlane ios clean_all_testers
```

### ios certs
```
fastlane ios certs
```
Fetches the provisioning profiles so you can build locally and deploy to your device
### ios refresh_dsyms
```
fastlane ios refresh_dsyms
```

### ios refresh_beta_dsyms
```
fastlane ios refresh_beta_dsyms
```

### ios push_certs
```
fastlane ios push_certs
```
Fetches the push notification certificates and saves them as p12 files in push_certs/, perfect for direct upload to AWS SNS. p12 password is password.
### ios icons
```
fastlane ios icons
```
Generate proper icons for all build trains
### ios update_swiftgen_config
```
fastlane ios update_swiftgen_config
```
Update switftgen input/output files
### ios update_strings
```
fastlane ios update_strings
```
Download latest localization files from Lokalize
### ios update_lokalise_metadata
```
fastlane ios update_lokalise_metadata
```
Upload App Store Connect metadata to Lokalise
### ios update_asc_metadata
```
fastlane ios update_asc_metadata
```
Download App Store Connect metadata from Lokalise and upload to App Store Connect Connect
### ios bump_build
```
fastlane ios bump_build
```
Bump build number
### ios set_version
```
fastlane ios set_version
```
Set version number
### ios ci
```
fastlane ios ci
```
Continous Integration
### ios test
```
fastlane ios test
```
Run tests
### ios asc
```
fastlane ios asc
```
Submit a new beta build to TestFlight

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
