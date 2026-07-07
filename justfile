# Home Assistant for Apple Platforms - task runner
#
# Requires `just` (https://github.com/casey/just): brew install just
# Also needs Xcode 26.4+ and Ruby 3.1.2 active (rbenv / mise / Homebrew ruby@3.1);
# see README.md "Getting Started" for the Ruby toolchain setup.
#
# Run `just` with no arguments to list the available commands.

workspace := "HomeAssistant.xcworkspace"
derived_data := "build/DerivedData"

# Simulator devices used by the run-* commands. Override on the CLI, e.g.
#   just run-ios device="iPhone 16 Pro"
#   just run-watch device="Apple Watch Series 9 (45mm)"
ios_device := "iPhone 17"
watch_device := "Apple Watch Series 10 (46mm)"

# Silence Xcode's interactive macro / package-plugin trust prompts on the CLI.
build_flags := "-skipMacroValidation -skipPackagePluginValidation"

# List the available commands.
default:
    @just --list

# 1. Set up the dev environment: Ruby gems + CocoaPods/SPM dependencies.
setup:
    bundle install
    bundle exec pod install --repo-update

# 2. Build and run the iOS app (Debug) on a simulator.
run-ios device=ios_device:
    xcodebuild build \
        -workspace {{workspace}} \
        -scheme App-Debug \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name={{device}}' \
        -derivedDataPath {{derived_data}} \
        {{build_flags}}
    open -a Simulator
    xcrun simctl boot "{{device}}" 2>/dev/null || true
    xcrun simctl install "{{device}}" "{{derived_data}}/Build/Products/Debug-iphonesimulator/Home Assistant.app"
    xcrun simctl launch "{{device}}" "$(plutil -extract CFBundleIdentifier raw '{{derived_data}}/Build/Products/Debug-iphonesimulator/Home Assistant.app/Info.plist')"

# 3. Build and run the watchOS app (Debug) on a watch simulator.
run-watch device=watch_device:
    xcodebuild build \
        -workspace {{workspace}} \
        -scheme WatchApp \
        -configuration Debug \
        -destination 'platform=watchOS Simulator,name={{device}}' \
        -derivedDataPath {{derived_data}} \
        {{build_flags}}
    open -a Simulator
    xcrun simctl boot "{{device}}" 2>/dev/null || true
    xcrun simctl install "{{device}}" "{{derived_data}}/Build/Products/Debug-watchsimulator/HomeAssistant-WatchApp.app"
    xcrun simctl launch "{{device}}" "$(plutil -extract CFBundleIdentifier raw '{{derived_data}}/Build/Products/Debug-watchsimulator/HomeAssistant-WatchApp.app/Info.plist')"

# 4. Build and run the Mac Catalyst app (Debug).
run-mac:
    xcodebuild build \
        -workspace {{workspace}} \
        -scheme App-Debug \
        -configuration Debug \
        -destination 'platform=macOS,variant=Mac Catalyst' \
        -derivedDataPath {{derived_data}} \
        {{build_flags}}
    open "{{derived_data}}/Build/Products/Debug-maccatalyst/Home Assistant.app"

# 5. Run all unit tests (Tests-Unit scheme, iOS simulator).
test:
    bundle exec fastlane test
