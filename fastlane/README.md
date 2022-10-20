fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### lint

```sh
[bundle exec] fastlane lint
```



### autocorrect

```sh
[bundle exec] fastlane autocorrect
```



### download_provisioning_profiles

```sh
[bundle exec] fastlane download_provisioning_profiles
```



### import_provisioning_profiles

```sh
[bundle exec] fastlane import_provisioning_profiles
```



### update_dsyms

```sh
[bundle exec] fastlane update_dsyms
```



### update_notification_test_cases

```sh
[bundle exec] fastlane update_notification_test_cases
```

Update the test cases from the fcm repo

### icons

```sh
[bundle exec] fastlane icons
```

Generate proper icons for all build trains

### update_swiftgen_config

```sh
[bundle exec] fastlane update_swiftgen_config
```

Update switftgen input/output files

### update_strings

```sh
[bundle exec] fastlane update_strings
```

Download latest localization files from Lokalize

### push_strings

```sh
[bundle exec] fastlane push_strings
```

Upload localized strings to Lokalise

### unused_strings

```sh
[bundle exec] fastlane unused_strings
```

Find unused localized strings

### update_lokalise_metadata

```sh
[bundle exec] fastlane update_lokalise_metadata
```

Upload App Store Connect metadata to Lokalise

### update_asc_metadata

```sh
[bundle exec] fastlane update_asc_metadata
```

Download App Store Connect metadata from Lokalise and upload to App Store Connect Connect

### set_version

```sh
[bundle exec] fastlane set_version
```

Set version number

### setup_ha_ci

```sh
[bundle exec] fastlane setup_ha_ci
```

Setup Continous Integration

### test

```sh
[bundle exec] fastlane test
```

Run tests

----


## iOS

### ios build

```sh
[bundle exec] fastlane ios build
```



### ios size

```sh
[bundle exec] fastlane ios size
```



----


## Mac

### mac build

```sh
[bundle exec] fastlane mac build
```



----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
