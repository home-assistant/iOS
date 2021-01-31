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
### clean_all_testers
```
fastlane clean_all_testers
```

### download_provisioning_profiles
```
fastlane download_provisioning_profiles
```

### import_provisioning_profiles
```
fastlane import_provisioning_profiles
```

### update_dsyms
```
fastlane update_dsyms
```

### refresh_dsyms
```
fastlane refresh_dsyms
```

### refresh_beta_dsyms
```
fastlane refresh_beta_dsyms
```

### push_certs
```
fastlane push_certs
```
Fetches the push notification certificates and saves them as p12 files in push_certs/, perfect for direct upload to AWS SNS. p12 password is password.
### icons
```
fastlane icons
```
Generate proper icons for all build trains
### update_swiftgen_config
```
fastlane update_swiftgen_config
```
Update switftgen input/output files
### update_strings
```
fastlane update_strings
```
Download latest localization files from Lokalize
### push_strings
```
fastlane push_strings
```
Upload localized strings to Lokalise
### update_lokalise_metadata
```
fastlane update_lokalise_metadata
```
Upload App Store Connect metadata to Lokalise
### update_asc_metadata
```
fastlane update_asc_metadata
```
Download App Store Connect metadata from Lokalise and upload to App Store Connect Connect
### set_version
```
fastlane set_version
```
Set version number
### setup_ha_ci
```
fastlane setup_ha_ci
```
Setup Continous Integration
### test
```
fastlane test
```
Run tests

----

## iOS
### ios build
```
fastlane ios build
```


----

## Mac
### mac build
```
fastlane mac build
```


----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
