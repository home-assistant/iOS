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
pattern). The iOS/watchOS targets and their CocoaPods integration are untouched —
iOS builds green at every step. CocoaPods cannot vend one target for two platforms,
so the macOS targets consume the same dependencies via **SPM** instead:

| Target | What | Dependencies |
|---|---|---|
| `App-macOS` | Native SwiftUI app shell (`Sources/App/macOS/`) | (Shared-macOS once it compiles) |
| `Shared-macOS` | `Shared.framework` for macOS — clones Shared-iOS's exact 306-file source list, same file references | 16 SPM products (HAKit, GRDB, Realm, Alamofire, PromiseKit, ObjectMapper, Sodium, KeychainAccess, Reachability, SFSafeSymbols, UIColorHexSwift, Version, XCGLogger, Starscream, SharedPush, ZIPFoundation) |

Verified working: `App-macOS` builds and renders the HA Lovelace dashboard natively
(arm64). `Shared-macOS` resolves its full SPM graph and compiles with a measured,
shrinking error count (baseline 306).

## How the project is edited

The `xcodeproj` Ruby gem cannot open this project; target surgery is scripted,
additive-only, in `Tools/`:

- `add_macos_app_target.py` — created `App-macOS` (UUID prefix `FAB0`)
- `add_macos_shared_target.py` — created `Shared-macOS` + SPM packages (`FAB2`)
- `add_files_to_target.py <target> <paths…>` — add mac-only files (`FAB4`)
- `link_shared_to_macapp.py` — dependency + link + embed Shared into the app (`FAB5`)

Run `plutil -lint HomeAssistant.xcodeproj/project.pbxproj` after any edit.

## Porting rules (Shared sources)

1. iOS/watchOS code paths stay byte-identical — guards only *wrap*.
2. Use `#if !os(macOS)` for iOS/watch-only features (`os(iOS)` would break the
   watch target, which compiles many of the same files).
3. `#if canImport(UIKit) import UIKit #else import AppKit #endif` for imports.
4. `Sources/Shared/Common/CrossPlatform/CrossPlatformUI.swift` (member of
   Shared-macOS only; inert on UIKit platforms) bridges the resource layer:
   `UIColor→NSColor`, `UIImage→NSImage`, `UIFont→NSFont`, `UIBezierPath`,
   `UIEdgeInsets`, UIKit-named semantic colors, no-op haptics. View-hierarchy types
   are **not** aliased — mac equivalents are SwiftUI.
5. SiriKit intent types come from `Intents.intentdefinition` codegen
   (`INTENTS_CODEGEN_LANGUAGE=Swift`, public codegen attribute), same as iOS.
6. HAKit's PromiseKit integration isn't exported by its SPM manifest — two
   public-API-only files are vendored at `Sources/Shared/Vendor/HAKitPromiseKit/`
   (Shared-macOS member only; iOS gets them from the `HAKit/PromiseKit` pod subspec).

### Known platform substitutions

| iOS | macOS |
|---|---|
| `UIDevice.current.name` | `Host.current().localizedName` |
| `UIApplication.shared.open` | `NSWorkspace.shared.open` |
| `UIScreen.main` | `NSScreen.main` |
| `UIGraphicsImageRenderer` | `NSImage(size:flipped:drawingHandler:)` |
| Haptics | no-op stubs |
| Dynamic Island toast, CarPlay, WatchConnectivity, Live Activities, NEHotspotNetwork, CoreMotion activity/altimeter, AVAudioSession | excluded via `#if !os(macOS)` (no macOS equivalent) |

### SPM gotcha

The `bgoncal/Starscream` `4.0.9` tag was moved upstream; SPM's fingerprint cache
rejects re-resolution by version. Starscream is pinned by **revision**
(`aaaf609d07eb487b2fccbe77f6267cf0843e2b19`).

## Build & run

```bash
# native macOS app
xcodebuild build -workspace HomeAssistant.xcworkspace -scheme App-macOS \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
# Shared for macOS
xcodebuild build -workspace HomeAssistant.xcworkspace -scheme Shared-macOS \
  -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

In Xcode: open the workspace, pick the `App-macOS` scheme, run. Debug builds honor
the `HA_MAC_DEFAULT_URL` env var and write a navigation trace to
`/tmp/ha-mac-trace.log`.

## Roadmap to Catalyst parity

1. ✅ App shell runs; frontend loads natively (login via HA web UI, persistent).
2. 🔄 `Shared-macOS` compiles (error burn-down in progress; baseline 306).
3. Link Shared into the app (`Tools/link_shared_to_macapp.py`): real server
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
