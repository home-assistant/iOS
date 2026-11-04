# Native macOS port — single-project architecture

Goal: `HomeAssistant.xcodeproj` builds **native iOS and native macOS** apps (no Mac
Catalyst), both rendering the Home Assistant frontend through `WKWebView`, sharing
the same `Shared` sources and reusing logic. Parity bar: everything the Catalyst
app supported, minus kiosk mode (dropped on macOS by decision).

> Native macOS is **not** Catalyst: `import UIKit` does not exist against the macOS
> SDK. UIKit-only code is branched with conditional compilation; mac equivalents are
> SwiftUI/AppKit.

## Targets

One project, sibling targets sharing sources (the standard Apple multiplatform
pattern). The iOS/watchOS targets are untouched — iOS builds green at every step.
Every dependency is already a Swift package on `main`, so the macOS targets reuse
the same package references with their own per-target product dependencies:

| Target | What | Dependencies |
|---|---|---|
| `App-macOS` | Native SwiftUI app shell (`Sources/App/macOS/`, a file-system-synchronized group) | Shared-macOS (dependency + link + embed) |
| `Shared-macOS` | `Shared.framework` for macOS — the same file-system-synchronized groups, membership exceptions and explicit top-level sources as Shared-iOS | the same package products as Shared-iOS (local HA* packages, SharedPush, PromiseKitDynamic, HAKit, GRDB, Alamofire, ObjectMapper, Sodium, KeychainAccess, SFSafeSymbols, XCGLogger, ZIPFoundation, swift-dependencies) minus MatterSupport, CoreMediaIO and the MacBridge plugin |

Status after rebasing onto `main` (November 2026): the project parses and both
targets are listed; neither has been compiled against the current `main` yet. The
earlier burn-down (baseline 306 errors in Shared-macOS) predates the Realm removal,
the CocoaPods → SPM move and the synchronized-group layout, so expect a new baseline.

## How the project is edited

The `xcodeproj` Ruby gem cannot open this project; target surgery is scripted,
additive-only, in `Tools/add_macos_targets.py`. It is idempotent and derives
everything from the current Shared-iOS target, so after a merge from `main` that
mangles the macOS targets the recovery is: restore `main`'s `project.pbxproj`, run
the script, `plutil -lint HomeAssistant.xcodeproj/project.pbxproj`. UUID prefixes:
`FAB0`/`FAB5` for App-macOS, `FAB2` for Shared-macOS, `FAB3` for generated objects.

Mac-only files need no registration: anything under a synchronized group that
Shared-iOS compiles is compiled by Shared-macOS too, so platform-specific code is
guarded with `#if` rather than excluded per target.

## Porting rules (Shared sources)

1. iOS/watchOS code paths stay byte-identical — guards only *wrap*.
2. Use `#if !os(macOS)` for iOS/watch-only features (`os(iOS)` would break the
   watch target, which compiles many of the same files).
3. `#if canImport(UIKit) import UIKit #else import AppKit #endif` for imports.
4. `Sources/Shared/Common/CrossPlatform/CrossPlatformUI.swift` (compiled
   everywhere, active only where AppKit exists without UIKit) bridges the resource layer:
   `UIColor→NSColor`, `UIImage→NSImage`, `UIFont→NSFont`, `UIBezierPath`,
   `UIEdgeInsets`, UIKit-named semantic colors, no-op haptics. View-hierarchy types
   are **not** aliased — mac equivalents are SwiftUI.
5. SiriKit intent types come from `Intents.intentdefinition` codegen
   (`INTENTS_CODEGEN_LANGUAGE=Swift`, public codegen attribute), same as iOS.
6. HAKit's PromiseKit integration comes from the local `PromiseKitDynamic`
   package, like every other target.

### Known platform substitutions

| iOS | macOS |
|---|---|
| `UIDevice.current.name` | `Host.current().localizedName` |
| `UIApplication.shared.open` | `NSWorkspace.shared.open` |
| `UIScreen.main` | `NSScreen.main` |
| `UIGraphicsImageRenderer` | `NSImage(size:flipped:drawingHandler:)` |
| Haptics | no-op stubs |
| Dynamic Island toast, CarPlay, WatchConnectivity, Live Activities, NEHotspotNetwork, CoreMotion activity/altimeter, AVAudioSession | excluded via `#if !os(macOS)` (no macOS equivalent) |

## Build & run

```bash
# native macOS app
xcodebuild build -project HomeAssistant.xcodeproj -scheme App-macOS \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
# Shared for macOS
xcodebuild build -project HomeAssistant.xcodeproj -scheme Shared-macOS \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

In Xcode: open the project, pick the `App-macOS` scheme, run. Debug builds honor
the `HA_MAC_DEFAULT_URL` env var and write a navigation trace to
`/tmp/ha-mac-trace.log`.

## Roadmap to Catalyst parity

1. ✅ App shell runs; frontend loads natively (login via HA web UI, persistent).
2. 🔄 `Shared-macOS` compiles (error burn-down to redo against current `main`).
3. Shared is already linked and embedded into the app: real server
   management/onboarding replaces the URL field; `Current` environment boots.
4. App layer: mac Settings scene (Settings views in Shared/App are largely SwiftUI),
   onboarding flow, external message bus + `WebViewController` feature parity in the
   mac web host (key commands → native menus, find-in-page, camera/mic permissions).
5. Extensions: macOS Widgets (WidgetKit supports macOS), notifications
   (UNUserNotificationCenter), push via SharedPush, menu-bar item (fold in the old
   MacBridge `NSStatusItem` logic natively), sensors (battery/network via IOKit —
   replacing MacBridge impls), App Intents/Shortcuts.
6. Cleanup: drop Catalyst from the `App` target (`SUPPORTS_MACCATALYST = NO`),
   retire `Launcher`/`MacBridge` once their features are native, CI scheme.

Out of scope on macOS: CarPlay, Watch pairing, Live Activities, Dynamic Island,
NFC, kiosk mode (dropped).
