# CocoaPods Acknowledgements

A CocoaPods plugin that generates a plist which includes the installation metadata. It supports generating two styles of dependency information.

* **Settings.bundle compatible plist** - This format is supported by a [large amount of pods](https://cocoapods.org/?q=acknow) and works with Apple's Settings.app.

* **Full Podspec metadata plist** - This format provides more information to the app allowing for deeper introspection, currently only [CPDAcknowledgements](https://github.com/cocoapods/CPDAcknowledgements) works with this format.

### Installation

Install via `gem install cocoapods-acknowledgements` you need to be using at least CocoaPods `0.36` and add `plugin 'cocoapods-acknowledgements'` to your `Podfile`. See below for examples:

### Example usage

For showing your own UI inside your application:

``` ruby
plugin 'cocoapods-acknowledgements'
```

For embedding a `Settings.bundle` compatible plist

``` ruby
plugin 'cocoapods-acknowledgements', :settings_bundle => true
```

With a Settings.bundle compatible plist, offering the chance to run post-processing on the plist ( to add non-CocoaPods dependencies for example )

``` ruby
plugin 'cocoapods-acknowledgements', :settings_bundle => true , :settings_post_process => Proc.new { |settings_plist_path, umbrella_target|
  puts settings_plist_path
  puts umbrella_target.cocoapods_target_label
}
```

The plugin will search through the first two levels of your project to find a `Settings.bundle` file, and add the file to the bundle. If this is not enough for you, we'd love a PR.

You can also exclude some dependencies so they won't be added to the generated plists. This is useful when you don't want to add private dependencies.

```ruby
plugin 'cocoapods-acknowledgements', :settings_bundle => true, :exclude => 'PrivateKit'

plugin 'cocoapods-acknowledgements', :settings_bundle => true, :exclude => ['PrivateKit', 'SecretLib']
```
