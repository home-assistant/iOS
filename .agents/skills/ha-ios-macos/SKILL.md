---
name: ha-ios-macos
description: How the native macOS app is built from the shared iOS code. Use when a change touches anything under `#if os(macOS)`, when UIKit code needs an AppKit counterpart, when presenting or dismissing a SwiftUI screen from AppKit, when adding a Mac window, menu or sheet, when a screen looks wrong on the Mac, or when building and running the Mac app.
---

# The native macOS app

The same targets build for iOS, Mac Catalyst and native macOS (`SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx`). The deployment target is macOS 13.3 for the app and its extensions, what the Catalyst app already requires through iOS 16.4 and what the native app's SwiftUI windows need; the Widgets target asks for macOS 14.0, as its widgets are App Intents based. Release still archives the Catalyst app (`fastlane/lanes/macos.rb` passes the Catalyst destination explicitly now that the targets also build natively); there is no signing or provisioning for the native app yet, so it is a developer build. Native macOS is `#if os(macOS)`; under Catalyst `os(iOS)` is true. `Current.isCatalyst` means "running on a Mac" and is true for both Mac variants, and code that was `#if targetEnvironment(macCatalyst)` now reads `#if targetEnvironment(macCatalyst) || os(macOS)`: when in doubt about what the native app should do, do what the Catalyst app does. Leave code that never compiles for macOS alone, though: a file or region under `#if os(iOS)` or `#if !os(macOS)` gains nothing from `|| os(macOS)` or a `macOS x.y` availability clause.

## Build and run

```bash
xcodebuild -project HomeAssistant.xcodeproj -scheme App-Debug -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO build
```

`CODE_SIGNING_ALLOWED=NO` is for a machine without a Mac signing identity; the product still launches from `Build/Products/Debug/`. Such a build has no entitlements at all: no sandbox, no app group, no keychain access group and no push environment. That hides a whole class of problems, so do not read "works unsigned" as "works": keychain items are not shared with the extensions, widgets and the other extensions cannot reach the app's data, push registration fails, and Apple Events to other apps (revealing a file in the Finder through `NSWorkspace`, say) are refused silently. A window that is behind other windows is not painted by WebKit, so bring the app to the front before judging a blank frontend.

## The compatibility layer

Write a screen once; only the view layer is per platform.

- **Value types keep their UIKit names.** `UIColor`, `UIImage`, `UIFont`, `UIEdgeInsets`, `UIBezierPath` and the semantic colour names are aliases or extensions on AppKit in `Sources/HAIconic/Sources/Platform/AppKitCompatibility.swift`; `UIRectCorner`, `UIGraphicsImageRenderer`, `UIPasteboard` and the feedback generators are stand-in types in their own files next to it. `UIColor.rgbaComponents` and `UIColor.dynamic(light:dark:)` (`PlatformColor+Components.swift`) replace `getRed` and trait-based colours. These are covered by `HADesignSystem`'s package tests, which the `build-mac` CI job runs on macOS.
- **iOS-only SwiftUI modifiers have Mac stand-ins** in `Sources/HADesignSystem/Sources/Platform/SwiftUI+macOSCompatibility.swift` (`navigationBarTitleDisplayMode`, `fullScreenCover` → sheet, `keyboardType`, `listSectionSpacing`, …), with the enums they take in their own files next to it. They exist so a modifier does not need an `#if` at every use; add to that file rather than sprinkling `#if os(macOS)` around modifiers.
- **A transparent `WKWebView`** is `makeBackgroundTransparent()` (`WKWebView+TransparentBackground.swift`): `drawsBackground` is not API on macOS, so it is set through key-value coding, guarded by `responds(to:)` so a WebKit that drops the key leaves the page opaque rather than crashing.
- **Views, controllers and windows are not aliased.** `PlatformView`, `PlatformViewController`, `PlatformWindow`, `PlatformHostingController` (`Sources/Shared/Common/PlatformTypes.swift`) are for code that only passes them along. Anything that builds a view is written per platform with real AppKit (`NSViewRepresentable`, `NSViewControllerRepresentable`) or, better, plain SwiftUI.
- **`NavigationView` is a stack on the Mac.** `Sources/App/Utilities/NavigationView.swift` takes the name over for the app target on macOS and wraps `NavigationStack`, because SwiftUI's own `NavigationView` always lays out in columns there.
- **Lifecycle:** `AppLifecycle.*Notification` and `ApplicationState.current` instead of `UIApplication`. A Mac app is never in the background.
- **Alerts from non-SwiftUI code** are described with `AppAlert` and shown with `appCoordinator.present(alert:)`. Mark the action the user most likely wants `isPreferred`; `NSAlert` orders its buttons from the right and only the preferred one gets the default key equivalent, which `macButtonOrder` takes care of.
- **Location:** never set `allowsBackgroundLocationUpdates` on macOS; Core Location throws, and an exception thrown during launch leaves every SwiftUI `List` in the process empty.

## Presenting SwiftUI screens from AppKit

SwiftUI's `dismiss` action does nothing inside an `NSHostingController` that AppKit presented. So AppKit code never calls `presentAsSheet` on a SwiftUI screen; it calls `presentSheet(_:)` (`Sources/App/Utilities/MacSheet/`), which takes the screen back out of the hosting controller and shows it in a sheet SwiftUI owns. `presentedSheets`, `dismissSheet()` and `dismissPresentedSheets()` are the counterparts of the UIKit presentation calls the shared code uses; `WebViewController` and `AppContainerCoordinator` route through them.

- A controller that called `presentsAsTransparentOverlay()` (a bottom sheet drawn over the frontend on iOS) gets a sheet sized to its content; every other screen opens at `preferredContentSize` or a phone-like default.
- `AppleLikeBottomSheet` reads `\.isPresentedInMacSheet` and draws only its card inside such a sheet. Set that environment value whenever a Mac sheet stands in for an iOS full-screen presentation.

## Screens

- **Settings rows use `GroupedList`**: the rule and what counts as a settings screen are in the `ha-ios-ui` skill. On the Mac it is a grouped `Form`, where buttons are `.borderless` so a row's action reads as a row rather than a push button with its own bezel, and `.listRowBackground` is ignored, so content that must sit outside a card (a logo, a hint) goes in the `header:` of an otherwise empty `Section`. A plain `List` on the Mac is a table that cuts every section footer to one line. A `Form` that is not a `GroupedList` is only for a screen that is a form on iOS too.
- **`dismiss` and pushed pages:** a view that reads `@Environment(\.dismiss)` and also drives a `navigationDestination(isPresented:)` from its own state is re-evaluated forever on the Mac, because the action changes each time the destination is rebuilt and the destination is rebuilt each time the view is (`OnboardingServersListView` was the case). Reading `dismiss` next to a plain `NavigationLink` is fine. When the loop appears, read the action in a leaf instead: `.dismiss(when:)` (`DismissWhenModifier`). A screen that is the content of a Settings window pane rather than a sheet must not `dismiss()` itself when its model goes away (a deleted server): `SettingsView` resets the sidebar selection instead.
- **Windows** are SwiftUI scenes in `HAApp` (main `WindowGroup`, `Window` scenes for Settings, About and Assist, a `WindowGroup` for adding a server). Code outside the scene graph opens them through `MacWindowOpener` / `Current.sceneManager.activateAnyScene(for:)`; `SceneActivity.initialWindowSize` sets first-launch sizes.
- **Menus** are SwiftUI `Commands` (`MainWindowGroupCommands`, `AppMenuBarCommands`, `MacWebViewCommands`); the Dock menu is `applicationDockMenu` in `AppDelegate`; the menu bar item is `StatusItemManager` over `MacBridge`.
- **The frontend window** is `WebViewController` on both platforms (an `NSViewController` on macOS) with `MacWebViewTitleBar` providing the toolbar and `NSTextFinder` the find bar.

## Extensions

Widgets, Intents, NotificationService, NotificationContent and Share build for macOS from the same targets; NotificationContent has its own `Info-macOS.plist` (a principal class instead of a storyboard). New files under `Sources/Extensions` must be listed in the project's exception sets like their neighbours, because that folder is owned by the Widgets target.

## What the native app does not do

CarPlay, Apple Watch complications, NFC, kiosk mode, gestures and app icon shortcuts are compiled out or hidden, exactly as they were under Catalyst.
