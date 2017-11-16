fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

## Choose your installation method:

<table width="100%" >
<tr>
<th width="33%"><a href="http://brew.sh">Homebrew</a></th>
<th width="33%">Installer Script</th>
<th width="33%">RubyGems</th>
</tr>
<tr>
<td width="33%" align="center">macOS</td>
<td width="33%" align="center">macOS</td>
<td width="33%" align="center">macOS or Linux with Ruby 2.0.0 or above</td>
</tr>
<tr>
<td width="33%"><code>brew cask install fastlane</code></td>
<td width="33%"><a href="https://download.fastlane.tools">Download the zip file</a>. Then double click on the <code>install</code> script (or run it in a terminal window).</td>
<td width="33%"><code>sudo gem install fastlane -NV</code></td>
</tr>
</table>

# Available Actions
## iOS
### ios certs
```
fastlane ios certs
```
Fetches the provisioning profiles so you can build locally and deploy to your device
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
### ios localize
```
fastlane ios localize
```
Download latest localization files from Lokalize
### ios update_lokalise
```
fastlane ios update_lokalise
```
Upload iTunes Connect metadata to Lokalise
### ios update_itunes
```
fastlane ios update_itunes
```
Download iTunes metadata from Lokalise and upload to iTunes Connect
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
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
