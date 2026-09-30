---
name: ha-ios-macos
description: How the native macOS app is built from the shared iOS code. Use when a change touches anything under `#if os(macOS)`, when UIKit code needs an AppKit counterpart, when presenting or dismissing a SwiftUI screen from AppKit, when adding a Mac window, menu or sheet, when a screen looks wrong on the Mac, or when building and running the Mac app.
---

# The native macOS app

The same targets build for iOS, Mac Catalyst and native macOS (`SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx`, deployment target macOS 13.3). Native macOS is `#if os(macOS)`; under Catalyst `os(iOS)` is true. `Current.isCatalyst` means "running on a Mac" and is true for both Mac variants, and code that was `#if targetEnvironment(macCatalyst)` now reads `#if targetEnvironment(macCatalyst) || os(macOS)`: when in doubt about what the native app should do, do what the Catalyst app does.

## Build and run

```bash
xcodebuild -project HomeAssistant.xcodeproj -scheme App-Debug -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO build
```

`CODE_SIGNING_ALLOWED=NO` is for a machine without a Mac signing identity; the product still launches from `Build/Products/Debug/`. A window that is behind other windows is not painted by WebKit, so bring the app to the front before judging a blank frontend.

## The compatibility layer

Write a screen once; only the view layer is per platform.

- **Value types keep their UIKit names.** `UIColor`, `UIImage`, `UIFont`, `UIEdgeInsets`, `UIBezierPath`, `UIRectCorner`, `UIGraphicsImageRenderer`, `UIPasteboard`, the feedback generators and the semantic colour names are aliases or stand-ins for AppKit in `Sources/HAIconic/Sources/Platform/AppKitCompatibility.swift`. `UIColor.rgbaComponents` and `UIColor.dynamic(light:dark:)` (`PlatformColor+Components.swift`) replace `getRed` and trait-based colours.
- **iOS-only SwiftUI modifiers have Mac stand-ins** in `Sources/HADesignSystem/Sources/Platform/SwiftUI+macOSCompatibility.swift` (`navigationBarTitleDisplayMode`, `fullScreenCover` → sheet, `keyboardType`, `listSectionSpacing`, …). They exist so a modifier does not need an `#if` at every use; add to that file rather than sprinkling `#if os(macOS)` around modifiers.
- **Views, controllers and windows are not aliased.** `PlatformView`, `PlatformViewController`, `PlatformWindow`, `PlatformHostingController` (`Sources/Shared/Common/PlatformTypes.swift`) are for code that only passes them along. Anything that builds a view is written per platform with real AppKit (`NSViewRepresentable`, `NSViewControllerRepresentable`) or, better, plain SwiftUI.
- **`NavigationView` is a stack on the Mac.** `Sources/App/Utilities/NavigationView.swift` takes the name over for the app target on macOS and wraps `NavigationStack`, because SwiftUI's own `NavigationView` always lays out in columns there.
- **Lifecycle:** `AppLifecycle.*Notification` and `ApplicationState.current` instead of `UIApplication`. A Mac app is never in the background.
- **Alerts from non-SwiftUI code** are described with `AppAlert` and shown with `appCoordinator.present(alert:)`.
- **Location:** never set `allowsBackgroundLocationUpdates` on macOS; Core Location throws, and an exception thrown during launch leaves every SwiftUI `List` in the process empty.

## Presenting SwiftUI screens from AppKit

SwiftUI's `dismiss` action does nothing inside an `NSHostingController` that AppKit presented. So AppKit code never calls `presentAsSheet` on a SwiftUI screen; it calls `presentSheet(_:)` (`Sources/App/Utilities/MacSheet/`), which takes the screen back out of the hosting controller and shows it in a sheet SwiftUI owns. `presentedSheets`, `dismissSheet()` and `dismissPresentedSheets()` are the counterparts of the UIKit presentation calls the shared code uses; `WebViewController` and `AppContainerCoordinator` route through them.

- A controller that called `presentsAsTransparentOverlay()` (a bottom sheet drawn over the frontend on iOS) gets a sheet sized to its content; every other screen opens at `preferredContentSize` or a phone-like default.
- `AppleLikeBottomSheet` reads `\.isPresentedInMacSheet` and draws only its card inside such a sheet. Set that environment value whenever a Mac sheet stands in for an iOS full-screen presentation.

## Screens

- **Settings rows use `GroupedList`** (`HADesignSystem`): a `List` on iOS, a grouped `Form` on the Mac. A plain `List` on the Mac is a table that cuts every section footer to one line, so it stays reserved for lists of data (large, reorderable or swipeable).
- **`dismiss` and pushed pages:** a view that both reads `@Environment(\.dismiss)` and builds a page pushed onto the stack (`navigationDestination(isPresented:)`, `NavigationLink(destination:)`) is re-evaluated forever on the Mac, because the action changes each time the pages are rebuilt. Read the action in a leaf instead: `.dismiss(when:)` (`DismissWhenModifier`).
- **Windows** are SwiftUI scenes in `HAApp` (main `WindowGroup`, `Window` scenes for Settings, About and Assist, a `WindowGroup` for adding a server). Code outside the scene graph opens them through `MacWindowOpener` / `Current.sceneManager.activateAnyScene(for:)`; `SceneActivity.initialWindowSize` sets first-launch sizes.
- **Menus** are SwiftUI `Commands` (`MainWindowGroupCommands`, `AppMenuBarCommands`, `MacWebViewCommands`); the Dock menu is `applicationDockMenu` in `AppDelegate`; the menu bar item is `StatusItemManager` over `MacBridge`.
- **The frontend window** is `WebViewController` on both platforms (an `NSViewController` on macOS) with `MacWebViewTitleBar` providing the toolbar and `NSTextFinder` the find bar.

## Extensions

Widgets, Intents, NotificationService, NotificationContent and Share build for macOS from the same targets; NotificationContent has its own `Info-macOS.plist` (a principal class instead of a storyboard). New files under `Sources/Extensions` must be listed in the project's exception sets like their neighbours, because that folder is owned by the Widgets target.

## What the native app does not do

CarPlay, Apple Watch complications, NFC, kiosk mode, gestures and app icon shortcuts are compiled out or hidden, exactly as they were under Catalyst.
