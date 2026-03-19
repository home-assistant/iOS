---
title: feat: iOS Live Activities for Home Assistant
type: feat
status: active
date: 2026-03-18
deepened: 2026-03-18
---

# feat: iOS Live Activities for Home Assistant

## Enhancement Summary

**Deepened on:** 2026-03-18
**Research agents used:** ActivityKit framework docs, APNs best practices, security sentinel, architecture strategist, performance oracle, spec-flow analyzer, code simplicity reviewer, async race conditions reviewer

### Key Improvements Added
1. **Critical process boundary constraint**: `PushProvider` (network extension) cannot call ActivityKit — it runs in a separate OS process. All handlers in the extension must relay to the main app via `UNUserNotificationCenter`. This would have caused silent failures at runtime.
2. **API version split**: The `Activity.request(attributes:contentState:pushType:)` API was deprecated in iOS 16.2 and replaced with `Activity.request(attributes:content:pushType:)` using `ActivityContent`. Code must handle both.
3. **iOS 18 rate limit change**: Apple changed update rate limiting to ~15s minimum between updates in iOS 18. Design must not assume 1 Hz is reliably achievable.
4. **Actor isolation required**: The `[String: Activity<T>]` dictionary will be accessed from multiple threads/queues. Must use a Swift `actor` with a reservation pattern to prevent TOCTOU races.
5. **Simplification**: Remove `updatedAt: Date` and `secondaryState` from MVP `ContentState`. Consolidate 3 handler files to 1. Use `Activity<T>.activities` instead of a parallel dictionary.
6. **Push-to-start unreliability**: Push-to-start from a fully terminated app has ~50% success rate. The primary flow must be foreground-initiated; push-to-start is best-effort only.
7. **Security**: Activity push tokens must be stored in Keychain (not `UserDefaults`), never logged to crash reporters, and only transmitted over the encrypted webhook channel.

### New Considerations Discovered
- `attributes-type` in APNs push-to-start payload must exactly match the Swift struct name — case-sensitive, immutable post-ship
- Certificate-based APNs auth is not supported for Live Activities; relay server must use JWT (`.p8` key)
- iOS 18 changes update budgets significantly; `NSSupportsLiveActivitiesFrequentUpdates` should be opt-in per activity
- `NotificationService` extension is never invoked for `apns-push-type: liveactivity` pushes
- iPad has `areActivitiesEnabled == false` — must handle gracefully without crash
- App must report capability (`supports_live_activities: Bool`) in registration payload so HA server can gate the UI

---

## Overview

Implement iOS Live Activities using Apple's ActivityKit framework so that Home Assistant automations can display real-time data on the iOS Lock Screen and Dynamic Island. This is a highly requested community feature (discussion #84). The Android companion app already ships this via persistent/ongoing notifications with tag-based in-place updates. The goal is **feature parity with Android** using the same notification field names so automations can target both platforms with minimal differences.

---

## Android Feature Baseline (What We're Matching)

The Android companion app has **two tiers** of live/updating notifications:

### Tier 1: `alert_once: true` + `tag` (any Android version)
Standard notifications updated in-place. Subsequent pushes with the same `tag` replace the notification without re-alerting.

### Tier 2: `live_update: true` (Android 16+ only) — the primary target
Android 16's native **Live Updates API**. Pins the notification to:
- Status bar as a **chip** showing `critical_text` or a live `chronometer`
- Lock screen (persistent, doesn't scroll away)
- Always-on display

This is the direct Android equivalent of iOS Live Activities.

```yaml
# Android 16+: Live Update with progress bar and countdown timer
action: notify.mobile_app_<device>
data:
  title: "Washing Machine"         # required for live_update
  message: "Cycle in progress"
  data:
    tag: washer_cycle              # unique ID for in-place updates
    live_update: true              # Android 16+: pin to status bar chip + lock screen
    critical_text: "45 min"        # short text shown in status bar chip
    progress: 2700                 # current value (raw integer)
    progress_max: 3600             # maximum value
    chronometer: true              # show countdown timer instead of critical_text
    when: 2700                     # seconds until done (for chronometer)
    when_relative: true            # treat `when` as duration, not timestamp
    notification_icon: mdi:washing-machine   # MDI icon for status bar chip
    notification_icon_color: "#2196F3"       # icon accent color
    alert_once: true               # also works on older Android: silent updates
    sticky: true                   # non-dismissible by user
    visibility: public             # visible on lock screen

# Android: dismiss it
action: notify.mobile_app_<device>
data:
  message: clear_notification
  data:
    tag: washer_cycle
```

**Key Android `live_update` fields:**

| Field | Type | Purpose |
|---|---|---|
| `live_update` | bool | Enable Android 16 Live Updates API |
| `tag` | string | Unique ID — same tag = update in-place |
| `title` | string | Required for `live_update` |
| `message` | string | Body text |
| `critical_text` | string | Short text in status bar chip |
| `chronometer` | bool | Show live countdown instead of `critical_text` |
| `when` | int | Seconds for the countdown / timestamp |
| `when_relative` | bool | Treat `when` as relative duration |
| `progress` | int | Current progress value (raw integer) |
| `progress_max` | int | Maximum progress value |
| `notification_icon` | string | MDI slug for status bar icon |
| `notification_icon_color` | string | Hex color for icon |
| `alert_once` | bool | Silence subsequent alerts (older Android fallback) |
| `sticky` | bool | Non-dismissible |
| `visibility` | string | `public` = visible on lock screen |

---

## Problem Statement / Motivation

Home Assistant users frequently need to monitor time-sensitive states (a washer finishing, a door left open, a timer counting down, a media player progress bar) without constantly opening the app. iOS 16.1 introduced Live Activities via ActivityKit specifically for this use case. Android users already have this capability. iOS companion app users have no equivalent.

---

## Proposed Solution

Implement iOS Live Activities triggered by the **same notification fields Android uses**. The iOS opt-in field `live_activity: true` mirrors Android's `live_update: true`. All other field names (`tag`, `title`, `message`, `progress`, `progress_max`, `chronometer`, `when`, `when_relative`, `notification_icon`, `notification_icon_color`) are shared between both platforms.

```yaml
# Works on BOTH Android 16+ and iOS 16.1+:

action: notify.mobile_app_<device>
data:
  title: "Washing Machine"
  message: "45 minutes remaining"
  data:
    tag: washer_cycle                      # iOS & Android: unique ID for in-place updates
    live_update: true                      # Android 16+: pin to status bar chip + lock screen
    live_activity: true                    # iOS 16.1+: use Live Activity (Android ignores)
    critical_text: "45 min"               # Android: status bar chip text. iOS: Dynamic Island compact trailing
    progress: 2700                         # iOS & Android: current value (raw integer)
    progress_max: 3600                     # iOS & Android: maximum value
    chronometer: true                      # iOS & Android: show countdown timer
    when: 2700                             # seconds remaining (used with chronometer)
    when_relative: true                    # treat `when` as duration from now
    notification_icon: mdi:washing-machine # iOS & Android: MDI icon slug
    notification_icon_color: "#2196F3"    # iOS & Android: icon accent color
    alert_once: true                       # Android: silent updates. iOS: ignored (always silent)
    sticky: true                           # Android: non-dismissible. iOS: ignored (always persistent)
    visibility: public                     # Android: lock screen. iOS: ignored (always public)

# Dismiss — identical on both platforms:
action: notify.mobile_app_<device>
data:
  message: clear_notification
  data:
    tag: washer_cycle
```

**iOS field mapping:**

| Companion docs field | iOS Live Activity mapping | Notes |
|---|---|---|
| `live_update: true` | — | Android-only opt-in; iOS uses `live_activity: true` |
| `live_activity: true` | Triggers Live Activity | Android ignores unknown fields |
| `tag` | `HALiveActivityAttributes.tag` | Same semantics: same tag = update in-place |
| `title` | `HALiveActivityAttributes.title` | Static attribute, set at activity creation |
| `message` | `ContentState.message` | Primary state text |
| `critical_text` | Dynamic Island compact trailing text | Short label (≤~10 chars) |
| `progress` | `ContentState.progress` | Raw integer |
| `progress_max` | `ContentState.progressMax` | Raw integer; fraction computed for SwiftUI |
| `chronometer: true` | `Text(timerInterval:countsDown:)` | Native iOS — zero battery cost, hardware-smooth |
| `when` + `when_relative` | Countdown end `Date` = `now + when` seconds | Converted to absolute `Date` for ActivityKit |
| `notification_icon` | `ContentState.icon` | MDI slug |
| `notification_icon_color` | `ContentState.color` | Hex string |
| `alert_once`, `sticky`, `visibility` | Ignored | Live Activities handle these natively |
| `clear_notification` + `tag` | Ends Live Activity + clears UNNotification | Same YAML, both platforms |

On iOS < 16.1 or iPad, `live_activity: true` is ignored and the notification falls through as a regular banner — graceful degradation with no automation changes needed.

The `ActivityAttributes` schema is wire-format stable: fields are only ever added, never renamed or removed, to maintain APNs compatibility across app updates.

---

## Technical Approach

### Architecture Overview

```
Home Assistant Automation
        │
        ▼
mobile_app service call  ──────────────────────────────────────┐
        │                                                       │
        ▼                                                       ▼
 FCM relay → APNs (remote)                    WebSocket push notification channel
 (start/update/end commands)                   (local push, LAN only)
        │                                                       │
        ▼                                                       ▼
 Main App Process                          Main App Process
 NotificationManager                       LocalPushManager
        │                                           │
        └─────────────────┬─────────────────────────┘
                          ▼
              NotificationCommandManager
              (handlers registered here)
                          │
                          ▼
              HandlerLiveActivity.swift    ← NEW (1 file, 3 structs)
                          │
                          ▼
              LiveActivityRegistry (actor) ← NEW
                          │
                          ▼
              Activity<HALiveActivityAttributes>
              (ActivityKit — main app ONLY)
                          │
                    ┌─────┴──────────────┐
                    ▼                    ▼
              Lock Screen          Dynamic Island
              View                 Views (compact,
                                   minimal, expanded)

⚠️  PushProvider (NEAppPushProvider) runs in a SEPARATE PROCESS.
    It cannot call ActivityKit. It must relay commands to the
    main app via UNUserNotificationCenter local push.
```

### iOS Version Requirements

| Feature | Minimum iOS |
|---|---|
| ActivityKit (basic) | **iOS 16.1** |
| `ActivityContent` / `staleDate` / updated API | **iOS 16.2** |
| Push-to-start (remote start) | **iOS 17.2** |
| `frequentPushesEnabled` user toggle | **iOS 17.2** |
| Current deployment target | iOS 15.0 |

All ActivityKit code must be wrapped in `#available(iOS 16.1, *)`. Use `#available(iOS 16.2, *)` for `ActivityContent` (the updated API). Push-to-start token registration must be wrapped in `#available(iOS 17.2, *)`. The UI must degrade gracefully on older OS versions (simply absent). iPad returns `areActivitiesEnabled == false` — must not crash.

### Critical API Version Split (iOS 16.1 vs 16.2)

The `Activity.request(...)` API changed in iOS 16.2. Both paths must be handled:

```swift
// iOS 16.1 only (deprecated — supports deployment target iOS 15+):
let activity = try Activity<HALiveActivityAttributes>.request(
    attributes: attributes,
    contentState: initialState,   // ← "contentState:" label
    pushType: .token
)

// iOS 16.2+ (preferred):
let content = ActivityContent(
    state: initialState,
    staleDate: Date().addingTimeInterval(30 * 60),
    relevanceScore: 0.5
)
let activity = try Activity<HALiveActivityAttributes>.request(
    attributes: attributes,
    content: content,             // ← "content:" label (ActivityContent wrapper)
    pushType: .token
)
```

Similarly, `activity.update(using:)` is iOS 16.1 only; use `activity.update(_:)` with `ActivityContent` on iOS 16.2+.

---

### Implementation Phases

#### Phase 1: Foundation — Data Model & Basic Local Start/End

**Goal:** Define the ActivityKit data model and be able to start/end a Live Activity from within the app (local only, no push).

**Tasks:**

- [ ] **`HALiveActivityAttributes.swift`** — Define the `ActivityAttributes` conforming struct in `Sources/Shared/LiveActivity/` behind `#if canImport(ActivityKit)`. This file must be compiled into BOTH the `iOS-App` target and `Extensions-Widgets` target (via `Shared.framework`). The `attributes-type` string in APNs payloads must exactly match the Swift struct name — **never rename this struct post-ship**.

  ```swift
  // Sources/Shared/LiveActivity/HALiveActivityAttributes.swift
  #if canImport(ActivityKit)
  import ActivityKit

  public struct HALiveActivityAttributes: ActivityAttributes {
      // Static: set once at activity creation, cannot change
      // These map from the initial notification payload fields
      public let tag: String           // = Android's `tag` field; unique ID for this activity
      public let title: String         // = Android's `title` field

      // Dynamic: updated via push or local update
      // Field names intentionally mirror Android companion docs notification fields
      public struct ContentState: Codable, Hashable {
          public var message: String          // = `message`. Primary state text
          public var criticalText: String?    // = `critical_text`. Short text for Dynamic Island compact trailing
          public var progress: Int?           // = `progress`. Current value (raw integer)
          public var progressMax: Int?        // = `progress_max`. Maximum value
          public var chronometer: Bool?       // = `chronometer`. If true, show countdown timer
          public var countdownEnd: Date?      // = computed from `when` + `when_relative`. Absolute end date for timer
          public var icon: String?            // = `notification_icon`. MDI slug
          public var color: String?           // = `notification_icon_color`. Hex string

          // Computed for SwiftUI rendering — not sent over wire
          public var progressFraction: Double? {
              guard let p = progress, let m = progressMax, m > 0 else { return nil }
              return Double(p) / Double(m)
          }
      }
  }
  #endif
  ```

  **Payload parsing note:** The handler reads standard notification fields and maps them:
  - `when` (int, seconds) + `when_relative: true` → `countdownEnd = Date().addingTimeInterval(Double(when))`
  - `when` as absolute Unix timestamp + `when_relative: false` → `countdownEnd = Date(timeIntervalSince1970: Double(when))`
  - `notification_icon` → `icon` (stored as-is, MDI slug)
  - `notification_icon_color` → `color` (same field semantics as Android `color`)

  **Design notes:**
  - All field names in JSON encoding match Android companion docs field names (via `CodingKeys`)
  - `progress`/`progress_max` are raw integers (matching Android) — `progressFraction` is computed for SwiftUI
  - `updatedAt: Date` omitted — system APNs timestamp handles ordering
  - `unit` deferred — add only when a specific layout requires it
  - Total encoded size of attributes + ContentState must stay under ~4KB (APNs limit)
  - **Never rename this struct or its fields post-ship** — `attributes-type` in APNs push-to-start payloads must match the Swift type name exactly

- [ ] **`LiveActivityRegistry.swift`** (actor) — in `Sources/Shared/LiveActivity/`:
  ```swift
  // actor protects concurrent access from push handler queue + token observer tasks
  actor LiveActivityRegistry {
      struct Entry {
          let activity: Activity<HALiveActivityAttributes>
          let observationTask: Task<Void, Never>
      }
      private var reserved: Set<String> = []   // TOCTOU protection
      private var entries: [String: Entry] = []

      /// Returns false if ID is already reserved or running (prevents duplicate start race)
      func reserve(id: String) -> Bool { ... }
      func confirmReservation(id: String, entry: Entry) { ... }
      func cancelReservation(id: String) { ... }
      func remove(id: String) -> Entry? { ... }
      func entry(for id: String) -> Entry? { ... }
  }
  ```
  Exposed via `AppEnvironment` as a protocol-typed property under `#if os(iOS)`, following the `notificationAttachmentManager` pattern.

- [ ] **`HandlerLiveActivity.swift`** — One file, three `private struct`s, in `Sources/Shared/Notifications/NotificationCommands/`, consistent with `HandlerUpdateComplications` and `HandlerUpdateWidgets` pattern:
  - `HandlerStartLiveActivity: NotificationCommandHandler`
  - `HandlerUpdateLiveActivity: NotificationCommandHandler`
  - `HandlerEndLiveActivity: NotificationCommandHandler`

- [ ] **Live Activity views** — in `Sources/Extensions/Widgets/LiveActivity/`:
  - `HALiveActivityConfiguration.swift` — `ActivityConfiguration` wrapper
  - `HALockScreenView.swift` — Lock Screen / StandBy view (max 160pt height)
  - `HADynamicIslandView.swift` — All Dynamic Island presentations

- [ ] **Register `ActivityConfiguration`** in `Sources/Extensions/Widgets/Widgets.swift` inside `WidgetsBundle18` with `#available(iOS 16.2, *)` guard

- [ ] **`Info.plist`** — Add `NSSupportsLiveActivities = true` to `Sources/App/Resources/Info.plist`

- [ ] **`AppEnvironment`** — Add `var liveActivityRegistry: LiveActivityRegistryProtocol` under `#if os(iOS)` to `Sources/Shared/Environment/Environment.swift`

- [ ] **App launch recovery** — In `LiveActivityRegistry.init()` or at startup, enumerate `Activity<HALiveActivityAttributes>.activities` to re-attach observation tasks to any activities that survived process termination. This must happen before any push handlers are invoked.

**Research Insights — Phase 1:**

**Xcode Preview support (no device needed for UI iteration):**
```swift
#Preview("Lock Screen", as: .content, using: HALiveActivityAttributes(activityID: "test", title: "Washer")) {
    HALiveActivityConfiguration()
} contentStates: {
    HALiveActivityAttributes.ContentState(state: "Running", value: 0.65, unit: nil, iconName: "mdi:washing-machine", color: "#4CAF50")
    HALiveActivityAttributes.ContentState(state: "Done", value: 1.0, unit: nil, iconName: "mdi:check-circle", color: "#2196F3")
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), ...) { ... }
#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), ...) { ... }
```

**Lock Screen height budget:** The system hard-truncates at **160 points**. Padding counts against this limit.

**Dynamic Island region layout:**
```swift
DynamicIsland {
    DynamicIslandExpandedRegion(.leading) { /* icon */ }
    DynamicIslandExpandedRegion(.trailing) { /* value + unit */ }
    DynamicIslandExpandedRegion(.center) { /* state text */ }
    DynamicIslandExpandedRegion(.bottom) { /* optional detail, full-width */ }
} compactLeading: { /* icon only */ }
  compactTrailing: { /* value, caption2 font */ }
  minimal: { /* single icon */ }
```

**Color rendering optimization:** Do NOT parse hex strings in the SwiftUI view body (runs on every render pass in SpringBoard). Pre-parse hex in `ContentState` decoding or use a cached extension:
```swift
// Add to ContentState
var resolvedColor: Color { Color(hex: color ?? "#FFFFFF") }
```

**`ActivityAuthorizationInfo` check before every start:**
```swift
guard ActivityAuthorizationInfo().areActivitiesEnabled else {
    // Report back to HA via webhook; do not crash
    return
}
```

**Success criteria:**
- A Live Activity can be started in-app on a physical iOS 16.1+ device
- The Lock Screen and Dynamic Island show the correct content
- Activity ends cleanly
- Xcode Preview shows all 4 presentations without a device
- On iOS < 16.1 or iPad, code paths are no-ops

---

#### Phase 2: Notification Command Integration (Local Push + APNs Update/End)

**Goal:** Enable HA automations to start, update, and end Live Activities via the existing notification command system. Push token is reported to HA so it can send APNs updates directly.

**Tasks:**

- [ ] **`HandlerLiveActivity`** — new `NotificationCommandHandler` registered for command `live_activity`, containing three private structs in one file:
  - **`HandlerStartOrUpdateLiveActivity`** — triggered when any notification arrives with `data.live_activity: true`
    - Reads from notification `data` dict: `tag` (required, becomes `activityID`), `title` (required), `message`, `progress`, `progress_max`, `color`, `icon`
    - Validates `tag`: max 64 chars, `[a-zA-Z0-9\-_]` only
    - If activity with `tag` already running → **update** (matches Android's tag-based replacement)
    - If not running → **start** new Live Activity (reservation pattern for TOCTOU safety)
    - Reports push token to HA server via webhook immediately after start
  - **`HandlerEndLiveActivity`** — triggered by `message: clear_notification` when notification also has a `tag` that matches a running Live Activity
    - Integrated into existing `HandlerClearNotification` — check if `tag` matches a running `Activity<HALiveActivityAttributes>`; if so, end it in addition to clearing the UNNotification
    - Optional `dismissal_policy` field: `immediate` (default), `default` (linger up to 4h), `after:<unix-timestamp>`
    - If no matching Live Activity, silently succeeds (existing `clear_notification` behavior preserved)

- [ ] **Modify `HandlerClearNotification`** — extend to also end any Live Activity whose `tag` attribute matches:
  ```swift
  // In HandlerClearNotification.handle(_:)
  if #available(iOS 16.1, *), let tag = payload["tag"] as? String {
      // End matching Live Activity if one exists
      if let activity = Activity<HALiveActivityAttributes>.activities
          .first(where: { $0.attributes.tag == tag }) {
          Task { await activity.end(nil, dismissalPolicy: .immediate) }
      }
  }
  // existing UNUserNotificationCenter.current().removeDeliveredNotifications(...)
  ```

- [ ] **Register `live_activity` command** in `NotificationsCommandManager.init()` under `#if os(iOS)`

**Platform parity table:**

| Android field | iOS handling | Notes |
|---|---|---|
| `tag` | `HALiveActivityAttributes.tag` (activityID) | Same field name, same semantics |
| `title` | `HALiveActivityAttributes.title` (static) | Same |
| `message` | `ContentState.message` | Same field name |
| `progress` | `ContentState.progress` | Same field name, raw integer |
| `progress_max` | `ContentState.progressMax` | Camel-cased in Swift, `progress_max` in JSON |
| `color` | `ContentState.color` | Same |
| `icon` | `ContentState.icon` | Same (MDI slug) |
| `alert_once` | Ignored — Live Activities are always silent on update | No action needed |
| `sticky` | Ignored — Live Activities are persistent by nature | No action needed |
| `visibility: public` | Always public on Lock Screen | No action needed |
| `live_activity: true` | Triggers Live Activity path | Android ignores unknown fields |
| `clear_notification` + `tag` | Ends Live Activity AND clears UNNotification | Same YAML works on both |

- [ ] **PushProvider relay** — `HandlerStartLiveActivity`, `HandlerUpdateLiveActivity`, and `HandlerEndLiveActivity` when running in `PushProvider` process must NOT call ActivityKit. Detect via `Current.isAppExtension` and relay via a local `UNNotificationRequest` instead:
  ```swift
  // In handler, inside PushProvider process:
  if Current.isAppExtension {
      let relay = UNMutableNotificationContent()
      relay.categoryIdentifier = "HA_LIVE_ACTIVITY_RELAY"
      relay.userInfo = payload
      let request = UNNotificationRequest(identifier: UUID().uuidString, content: relay, trigger: nil)
      UNUserNotificationCenter.current().add(request)
      return
  }
  // Otherwise (main app process), call ActivityKit directly
  ```
  The main app's `NotificationManager.userNotificationCenter(_:didReceive:)` handles the relayed notification and calls the registry.

- [ ] **Push token observation task** — Inside `LiveActivityRegistry`, for each started activity:
  ```swift
  let observationTask = Task {
      for await tokenData in activity.pushTokenUpdates {
          guard !Task.isCancelled else { break }
          let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
          // Wrap in background task to prevent suspension mid-report
          let bgTask = await UIApplication.shared.beginBackgroundTask(withName: "la-token-update")
          defer { UIApplication.shared.endBackgroundTask(bgTask) }
          await reportPushToken(tokenHex, activityID: activityID)
      }
      // Stream ends when activity ends — self-clean
      await remove(id: activityID)
  }
  ```

- [ ] **Activity lifecycle observer** — Inside the same task, also observe `activity.activityStateUpdates`:
  ```swift
  for await state in activity.activityStateUpdates {
      if state == .dismissed || state == .ended {
          await reportActivityDismissed(activityID: activityID, reason: state == .dismissed ? "user_dismissed" : "ended")
          await registry.remove(id: activityID)
          break
      }
  }
  ```

- [ ] **Push token reporting webhook** — POST to HA via existing `WebhookManager.send(server:request:)`, no new webhook response type needed:
  ```swift
  let request = WebhookRequest(
      type: "mobile_app_live_activity_token",
      data: ["activity_id": activityID, "push_token": tokenHex, "apns_environment": apnsEnvironment]
  )
  Current.webhooks.send(server: server, request: request)
  ```

- [ ] **Activity dismissal webhook** — POST `mobile_app_live_activity_dismissed` event to HA when activity state becomes `.dismissed` or `.ended` externally. This is critical so HA stops sending updates.

- [ ] **Capability advertisement** — Add `supports_live_activities: Bool` and `supports_live_activities_frequent_updates: Bool` and `min_live_activities_ios_version: "16.1"` to `buildMobileAppRegistration()` `app_data` dict in `HAAPI.swift`, under `#if os(iOS)` + `#available(iOS 16.1, *)`.

- [ ] **Server version gate** — Add to `AppConstants.swift`:
  ```swift
  public extension Version {
      static let liveActivities: Version = .init(major: 2026, minor: 6, prerelease: "any0")
  }
  ```

- [ ] **APNs environment tracking** — Determine sandbox vs production at registration time and include `apns_environment: "sandbox" | "production"` in every token report webhook. The relay server uses this to route to the correct APNs endpoint. Tokens from one environment are rejected by the other.

- [ ] **Update debounce** — Add a trailing-edge debounce (250ms minimum) in the update handler. High-frequency HA sensors can fire many events per second; the system silently drops excess `Activity.update(...)` calls after consuming CPU.

**Research Insights — Phase 2:**

**PromiseKit bridge pattern** (matches existing handler protocol):
```swift
struct HandlerStartLiveActivity: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()
        Task {
            do {
                try await LiveActivityRegistry.shared.start(payload: payload)
                seal.fulfill(())
            } catch ActivityAuthorizationError.activitiesDisabled {
                seal.fulfill(()) // User choice — not an error
            } catch ActivityAuthorizationError.globalMaximumExceeded {
                seal.reject(LiveActivityError.tooManyActivities)
            } catch {
                seal.reject(error)
            }
        }
        return promise
    }
}
```

**`ActivityAuthorizationError` cases to handle:**
- `.activitiesDisabled` — user turned off Live Activities in Settings → report to HA, no crash
- `.globalMaximumExceeded` — device limit hit (~2-3 concurrent) → report error to HA
- `.attributesTooLarge` — payload too big → reject with useful error message
- `.pushUpdatesDisabled` — iOS 17.2+ user toggle → report to HA so it knows not to send APNs updates

**iOS 18 rate limit reality:** Effective minimum update interval is ~15 seconds. HA automations should be designed to fire at most 4 times per minute for non-timer use cases. Build this guidance into companion documentation.

**Success criteria:**
- Sending `action: notify.mobile_app_<device>` with `message: start_live_activity` starts a Live Activity
- Sending `message: update_live_activity` updates state
- Sending `message: end_live_activity` dismisses the activity
- Push token is successfully delivered to HA server via encrypted webhook
- Activity dismissal (user swipe or 8-hour expiry) is reported back to HA server
- `supports_live_activities: true` appears in HA device registry

---

#### Phase 3: APNs Push-to-Start (Remote Start, iOS 17.2+)

**Goal:** Allow HA automations to start a Live Activity entirely remotely (app not required in foreground).

**⚠️ Important caveat:** Push-to-start from a fully terminated app succeeds only ~50% of the time. Design this as a best-effort enhancement, not the primary flow. The primary flow is notification command → app receives push → main app starts activity.

**Tasks:**

- [ ] **Push-to-start token observation** — In `LiveActivityRegistry` or `AppDelegate`:
  ```swift
  @available(iOS 17.2, *)
  func observePushToStartToken() {
      Task {
          for await tokenData in Activity<HALiveActivityAttributes>.pushToStartTokenUpdates {
              let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
              // Store in Keychain (NOT UserDefaults — higher-value secret)
              Current.keychain.set(tokenHex, forKey: "live_activity_push_to_start_token")
              await reportPushToStartToken(tokenHex)
          }
      }
  }
  ```

- [ ] **Registration payload extension** — Extend `buildMobileAppRegistration()` / `buildMobileAppUpdateRegistration()` in `HAAPI.swift` to include `live_activity_push_to_start_token` in `app_data` when available (iOS 17.2+ only).

- [ ] **`NSSupportsLiveActivitiesFrequentUpdates`** — Add to `Sources/App/Resources/Info.plist`. Required for push-to-start token to be issued. Also exposes user toggle in iOS Settings. Observe `ActivityAuthorizationInfo().activityEnablementUpdates` to detect when user toggles this off and report to HA.

- [ ] **`frequentPushesEnabled` reporting** — Report the current value of `ActivityAuthorizationInfo().frequentPushesEnabled` (iOS 17.2+) to HA via registration/update payload. HA server must not send high-frequency pushes when this is `false`.

- [ ] **APNs payload format** — Document in companion docs. Key constraints:
  - `attributes-type` must exactly match Swift struct name (`"HALiveActivityAttributes"`) — **immutable post-ship**
  - `apns-push-type: liveactivity` header required
  - `apns-topic: io.robbie.HomeAssistant.push-type.liveactivity`
  - JWT auth only (`.p8` key) — certificate auth is not supported for Live Activities
  - APNs environment must match token environment (sandbox vs production)

  ```json
  {
    "aps": {
      "timestamp": 1234567890,
      "event": "start",
      "content-state": {
        "state": "Running",
        "value": 0.65,
        "unit": null,
        "iconName": "mdi:washing-machine",
        "color": "#4CAF50"
      },
      "attributes-type": "HALiveActivityAttributes",
      "attributes": {
        "activityID": "washer-cycle-abc123",
        "title": "Washing Machine"
      },
      "alert": {
        "title": "Washer Started",
        "body": "Cycle in progress"
      },
      "stale-date": 1234571490,
      "relevance-score": 0.5
    }
  }
  ```

- [ ] **Relay server changes** (documented for HA core team) — The relay at `mobile-apps.home-assistant.io` must:
  - Add a new endpoint for Live Activity push forwarding (separate from standard notification path because APNs headers differ)
  - Support `apns-push-type: liveactivity` and the `.push-type.liveactivity` topic suffix
  - Cache the JWT in memory, rotate every 45 minutes (not per-request)
  - Route to sandbox vs production APNs endpoint based on `apns_environment` field from the app
  - Handle `BadDeviceToken (400)` response as a signal to invalidate the stored token

**Success criteria:**
- HA automation can start a Live Activity on iOS 17.2+ device without app being open (best-effort)
- Push-to-start token stored in Keychain, reported to HA via registration payload
- Token refresh handled automatically via `pushToStartTokenUpdates`
- Relay server routes to correct APNs environment

---

#### Phase 4: UI Polish & Settings

**Goal:** Provide configuration options and polished layouts.

**Tasks:**

- [ ] **Settings section** — Add "Live Activities" section to existing `NotificationSettingsViewController` hierarchy showing:
  - Live Activities enabled status (links to iOS Settings if disabled)
  - Active activities list (enumerate `Activity<HALiveActivityAttributes>.activities`)
  - "End All Activities" button
  - Frequent updates toggle status (iOS 17.2+)

- [ ] **Material Design Icon rendering** — Use existing `MaterialDesignIcons` integration (verify the font resource bundle is included in the Widgets extension target, as it is for standard widgets). MDI slugs decode at view construction time, not in the view body.

- [ ] **Privacy disclosure** — One-time warning when first Live Activity is started: "Live Activity content is visible on your Lock Screen without Face ID or Touch ID. Choose entities carefully." Stored as a `UserDefaults` seen-flag.

- [ ] **Timer layout** — Use `ActivityKit`'s native timer support to show countdown with zero additional push updates:
  ```swift
  Text(timerInterval: startDate...endDate, countsDown: true)
  ```
  No update pushes needed for timer progress — the system handles animation natively.

- [ ] **User-facing documentation** — Companion docs PR with automation YAML examples

**Deferred (separate issues):**
- `activityType` enum for specialized layouts — APNs schema compatibility risk; open a separate issue when demand is proven
- Multiple specialized `ActivityAttributes` types (media player, delivery tracking)

**Success criteria:**
- Users can see and manage active Live Activities from app settings
- Icons render correctly from MDI slugs
- Privacy disclosure shown once before first use
- Timers animate without any server-sent updates

---

## Alternative Approaches Considered

| Approach | Verdict | Reason |
|---|---|---|
| **Strongly-typed activity per use case** (TimerActivity, MediaActivity) | Rejected for MVP | Too prescriptive; HA's flexibility demands a generic model; APNs `attributes-type` string is immutable |
| **Separate Live Activity extension target** | Rejected | WidgetKit extension already exists; ActivityKit views belong in the same `Widgets` target |
| **WebSocket-only updates (no APNs)** | Phase 1-2 only (local push) | APNs push-to-start needed for background start; update pushes from relay for remote update |
| **`LiveActivityManager` class on AppEnvironment from day one** | Deferred | No testability requirement proven yet; call ActivityKit from handlers directly in Phase 1-2; extract manager when tests require mocking |
| **`[String: Activity<T>]` parallel dictionary** | Rejected | System provides `Activity<T>.activities` as authoritative list; parallel dictionary adds crash-recovery gap |
| **New `WebhookResponseLiveActivityToken` type** | Rejected | Existing `WebhookRequest(type:data:)` + `Current.webhooks.send(...)` handles token reporting without new types |

---

## System-Wide Impact

### Interaction Graph

`HA automation fires` → `mobile_app.send_message service` → `FCM relay` → `APNs` → `Main app NotificationManager.didReceiveRemoteNotification` → `NotificationCommandManager.handle(_:)` → `HandlerStartLiveActivity.handle(_:)` → `LiveActivityRegistry.reserve(id:)` → `Activity<HALiveActivityAttributes>.request(...)` → `Activity.pushTokenUpdates` async stream → `WebhookManager.send(...)` `mobile_app_live_activity_token` → `HA server stores token` → `HA server → relay → APNs update pushes directly to activity token`.

**PushProvider path** (separate process): `PushProvider receives push` → `NotificationCommandManager.handle(_:)` → `HandlerStartLiveActivity` detects `Current.isAppExtension == true` → posts relay `UNNotificationRequest` → `Main app NotificationManager.userNotificationCenter(_:didReceive:)` → same path as above.

### Error & Failure Propagation

- `Activity.request(...)` throws `ActivityAuthorizationError`:
  - `.activitiesDisabled` — user toggle off or iPad → report to HA via webhook event `mobile_app_live_activity_start_failed`, reason: `activities_disabled`; no user-visible error
  - `.globalMaximumExceeded` — system limit hit → report to HA, suggest ending existing activity
  - `.attributesTooLarge` — payload over ~4KB → log error with field sizes; do not surface crash
- Push token reporting failure (network offline) → `WebhookManager` retry logic handles it; the `pushTokenUpdates` stream will also re-emit on next rotation
- Activity dismissed externally → `activityStateUpdates` emits `.dismissed` → `LiveActivityRegistry` removes entry and POSTs `mobile_app_live_activity_dismissed` webhook to HA
- Activity reaches 8-hour system limit → same path as above; HA stops sending updates

### State Lifecycle Risks

- **App crash with activities running**: Activities persist on Lock Screen; `LiveActivityRegistry.activities` dictionary is in-memory only. On relaunch, `Activity<HALiveActivityAttributes>.activities` (system list) restores tracking. **Must call this at app launch before handling any push commands.**
- **TOCTOU duplicate start**: Two pushes arrive with same `activityID` — reservation pattern in `actor LiveActivityRegistry` prevents both from reaching `Activity.request(...)`. Second caller gets `false` from `reserve(id:)` and updates instead.
- **App update changes `ContentState`**: Adding optional fields is safe (APNs uses JSON, extras ignored). Removing or renaming fields breaks existing activities. Never rename `ContentState` properties post-ship.

### API Surface Parity

- `NotificationCommandManager` registers 3 new command handlers — both the main app and `PushProvider` initialize `NotificationCommandManager`; the `PushProvider` instance's handlers must relay, not execute, ActivityKit calls
- `HAAPI.buildMobileAppRegistration()` must include capability fields; `updateRegistration()` must also update them to handle token refresh and OS upgrade scenarios

### Integration Test Scenarios

1. Start activity via FCM push → token reported to HA → HA sends APNs update via relay → state visible on Lock Screen within 15s (iOS 18 rate limit budget)
2. App backgrounded → WebSocket local push arrives → activity updates without app foregrounding
3. Two simultaneous `start_live_activity` pushes with same `activityID` arrive 5ms apart → reservation pattern ensures only one activity created
4. iOS 15 device receives `start_live_activity` push → `#available` guard fires → `NotificationCommandManager` still processes other commands normally, no crash
5. Activity reaches 8-hour limit → `activityStateUpdates` fires → `mobile_app_live_activity_dismissed` webhook sent to HA → HA stops sending updates
6. `PushProvider` receives `start_live_activity` push → relay local notification posted → main app receives it → activity starts correctly

---

## Security Considerations

### Lock Screen Data Exposure (Critical)

Live Activity content is visible on the Lock Screen before Face ID/Touch ID authentication. This is not controllable at the OS level — any data in `ContentState` that the view renders may be seen by anyone who picks up the device.

**Required mitigations:**
- **Privacy consent gate**: Show a one-time alert before the first activity starts: "Live Activity content, including the entity state you choose, will be visible on your Lock Screen without authentication." Store seen-flag in `UserDefaults`.
- **Documentation**: Companion docs must explicitly warn users not to use Live Activities for alarm armed/disarmed state, lock status, presence information, or health data.
- **Redacted lock screen mode** (Phase 4): Allow users to opt into a "private" mode that shows only the activity title and icon on the lock screen, with full state only when unlocked.

### Push Token Security (High)

Activity push tokens are direct-to-device APNs credentials. If stolen, an attacker can push arbitrary content to an active Live Activity.

**Required mitigations:**
- **Keychain storage**: Push-to-start tokens must be stored in the Keychain, not `UserDefaults`. The existing push token (`pushID`) uses `UserDefaults` — do not follow this pattern for the more sensitive Live Activity tokens.
- **No crash reporter logging**: Activity push tokens and push-to-start tokens must NOT be set as crash reporter user properties. Do not follow the existing `APNS Token` / `FCM Token` pattern in `NotificationManager.swift` for these values.
- **Encrypted webhook only**: The `mobile_app_live_activity_token` webhook request must be sent only when `server.info.connection.webhookSecretBytes(version:)` is non-nil. If encryption is unavailable, queue and retry rather than sending plaintext.
- **Token invalidation on activity end**: When `HandlerEndLiveActivity` ends an activity, POST a `mobile_app_live_activity_dismissed` event so HA can discard the stored token.

### Source Authentication (High)

The existing `NotificationCommandManager` dispatches commands based on payload content alone, with no verification that the push originated from the registered HA server.

**Required mitigation**: `HandlerStartLiveActivity` must verify that the inbound push carries a `webhook_id` matching a registered server before calling ActivityKit. Use `ServerManager.server(for:)` at `Sources/Shared/API/ServerManager.swift` — this check already exists for routing but must be applied at the command handler level.

### Input Validation (Medium)

All server-supplied strings (`activityID`, `color`, `iconName`) must be validated before use:
- `activityID`: max 64 chars, `[a-zA-Z0-9\-_]` only
- `color`: must match `/^#?[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/` before passing to hex parser
- `iconName`: max 64 chars; the MDI lookup is safe by design (no filesystem access), but enforce length

None of these values should be interpolated raw into log statements.

---

## Performance Considerations

### Update Frequency

Apple's rate limiting changed significantly in iOS 18:
- **iOS 17 and earlier**: ~1 update/second sustained
- **iOS 18+**: ~15 seconds minimum between updates (enforced silently — the server receives HTTP 200 but the device ignores excess pushes)
- **With `NSSupportsLiveActivitiesFrequentUpdates`**: Higher budget, but still subject to iOS 18 device-level throttling

**Implication**: Design HA automations to send Live Activity updates only on actual state changes, not on a timer. A HA energy sensor updating every second should NOT trigger a push on every update — the automation should debounce or use a minimum change threshold.

**Client-side debounce**: The `HandlerUpdateLiveActivity` should impose a 250ms trailing-edge debounce before calling `Activity.update(...)`. High-frequency local push events (WebSocket) would otherwise submit excessive updates.

### Battery Impact

Each `Activity.update(...)` call wakes SpringBoard's render server (out-of-process). At 1 Hz sustained: ~3-5% additional battery drain per hour. Recommend the `NSSupportsLiveActivitiesFrequentUpdates` entitlement be surfaced to users as "High-frequency updates (increased battery usage)" — do not enable it unconditionally.

For timer-style countdowns: use `Text(timerInterval:countsDown:)` instead of sending value updates — the system animates the countdown natively at 0 battery cost.

---

## Acceptance Criteria

### Functional Requirements — Android Feature Parity (MVP)

- [ ] An existing Android Live Notification automation works on iOS with only the addition of `live_activity: true` in `data`
- [ ] `tag` field is used as the activity identifier — same `tag` updates the existing activity (no new one created)
- [ ] `title` and `message` display in the Live Activity (matching Android `title`/`message` fields)
- [ ] `progress` and `progress_max` display as a progress bar in the Live Activity (matching Android)
- [ ] `color` applies as the accent color (matching Android)
- [ ] `icon` renders the MDI icon slug (matching Android)
- [ ] `message: clear_notification` with `tag` ends both the Live Activity AND any delivered `UNNotification` with the same identifier
- [ ] On iOS < 16.1 or iPad, `live_activity: true` is ignored; a regular notification banner is shown instead (graceful fallback — no automation changes required)
- [ ] Sending a second notification with the same `tag` silently updates the existing activity (no dismissal, no sound — equivalent to Android's `alert_once: true` behavior)

### Functional Requirements — iOS Enhancements Beyond Android

- [ ] Activities display in the Dynamic Island (compact, minimal, expanded) in addition to Lock Screen
- [ ] On iOS 17.2+, a HA automation can remotely start a Live Activity without the app being open (best-effort)
- [ ] Push tokens are sent to HA server (encrypted webhook) so it can update activities via APNs directly
- [ ] Activity dismissal (user swipe, 8-hour limit) is reported back to HA via `mobile_app_live_activity_dismissed` webhook
- [ ] `supports_live_activities: true` appears in HA mobile app integration device registry
- [ ] Multiple concurrent activities are supported (respecting iOS system limits of ~2-3)
- [ ] Privacy consent alert shown once before first use

### Non-Functional Requirements

- [ ] No impact on startup time on devices not using Live Activities
- [ ] All code gated with `#available(iOS 16.1, *)` where required; `#if canImport(ActivityKit)` in Shared
- [ ] Live Activity views pass light/dark mode screenshot review on all Dynamic Island presentations
- [ ] Push tokens never logged to crash reporter (Crashlytics/Sentry)
- [ ] Push-to-start token stored in Keychain, not `UserDefaults`
- [ ] `activityID` input validated (max 64 chars, restricted charset) before use

### Quality Gates

- [ ] Linting passes: `bundle exec fastlane lint` (SwiftFormat + SwiftLint)
- [ ] Unit tests for `LiveActivityRegistry` actor (start/update/end/deduplication/TOCTOU reservation)
- [ ] Unit tests for each notification command handler (with mocked `LiveActivityRegistry`)
- [ ] Unit tests for `HandlerStartLiveActivity` in PushProvider context — verifies relay path, not ActivityKit call
- [ ] Manual test on physical device (iOS 16.1, iOS 16.2 for `ActivityContent` API, iOS 17.2+ for push-to-start)
- [ ] Screenshots for all Dynamic Island presentations (compact, minimal, expanded) and Lock Screen for PR

---

## Dependencies & Prerequisites

| Dependency | Status | Notes |
|---|---|---|
| ActivityKit (Apple) | Available, iOS 16.1+ | No CocoaPod needed — system framework |
| HA server-side support (`mobile_app` component) | **Required** | Must handle `supports_live_activities` in registration, `mobile_app_live_activity_token` webhook, and `mobile_app_live_activity_dismissed` event |
| Relay server changes | **Required for Phase 3** | Relay must support `apns-push-type: liveactivity`, JWT-only auth, sandbox/production routing |
| APNs entitlement | Already present | `aps-environment` entitlement exists |
| App Group | Already present | `group.io.robbie.homeassistant` used by Widgets |
| `NSSupportsLiveActivities` Info.plist key | **Missing** | Must be added in Phase 1 |
| `NSSupportsLiveActivitiesFrequentUpdates` | **Missing** | Add in Phase 3; surface as user toggle |
| Companion docs PR | Needed | Document automation YAML, privacy warnings, rate limit guidance |
| HA iOS deployment target clarification | Needed | iOS 16.1 minimum for any ActivityKit; current target is iOS 15.0 |

---

## Risk Analysis & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Server-side HA changes required before feature is useful | High | High | Phase 1–2 local push path works without server changes; file coordinated server PR early |
| `attributes-type` string locked post-ship | High | High | Never rename `HALiveActivityAttributes`; document as immutable in code comments |
| Push-to-start unreliable from terminated state | High | Medium | Document as best-effort; primary flow is foreground-initiated |
| iOS 18 rate limit breaks real-time use cases | High | Medium | Debounce on client, document 15s minimum in companion docs |
| ActivityKit called from PushProvider process | High | Critical | Guard with `Current.isAppExtension` check; add compile-time warning comment |
| Data race on registry dictionary | Medium | High | Swift actor eliminates this entirely |
| Push token exfiltration to crash reporter | Medium | High | Explicit code review checklist item: no token logging |
| Apple changes ActivityKit API (behavior differences) | Medium | Medium | Gate on `#available`; test on both iOS 16.1 and 17.x in CI |
| Lock Screen displays sensitive HA entity data | High | Medium | Privacy consent gate and companion docs warning (user choice remains theirs) |

---

## Key Files to Create / Modify

### New Files

```
Sources/Shared/LiveActivity/
├── HALiveActivityAttributes.swift     # ActivityAttributes + ContentState, field names match Android
└── LiveActivityRegistry.swift         # actor managing concurrent activity lifecycle + TOCTOU reservation

Sources/Extensions/Widgets/LiveActivity/
├── HALiveActivityConfiguration.swift  # ActivityConfiguration + WidgetBundle registration
├── HALockScreenView.swift             # Lock Screen view (max 160pt height; progress bar, icon, message)
└── HADynamicIslandView.swift          # Dynamic Island: compact / minimal / expanded presentations

Sources/Shared/Notifications/NotificationCommands/
└── HandlerLiveActivity.swift          # Handles live_activity: true flag and integration with clear_notification
```

### Modified Files

```
Sources/App/Resources/Info.plist
  → NSSupportsLiveActivities = true
  → NSSupportsLiveActivitiesFrequentUpdates = true (Phase 3)

Sources/Extensions/Widgets/Widgets.swift
  → Register HALiveActivityConfiguration in WidgetsBundle18 under #available(iOS 16.2, *)

Sources/Shared/Environment/Environment.swift
  → Add var liveActivityRegistry: LiveActivityRegistryProtocol (under #if os(iOS))

Sources/Shared/Notifications/NotificationCommands/NotificationsCommandManager.swift
  → Register live_activity command handler (under #if os(iOS))
  → Extend HandlerClearNotification to also end matching Live Activity by tag

Sources/Shared/API/HAAPI.swift
  → Add supports_live_activities, live_activity_push_to_start_token to registration payload

Sources/Shared/Environment/AppConstants.swift
  → Add Version.liveActivities constant
```

---

## Success Metrics

- Zero crash reports related to Live Activity on iOS < 16.1 or iPad (via Sentry)
- `mobile_app_live_activity_dismissed` webhook fires within 30s of user swiping away activity
- Feature adopted by community within 30 days of HA server support landing
- GitHub discussion #84 closed/referenced

---

## Open Questions (Require Resolution Before or During Implementation)

1. **Deployment target**: Should the iOS minimum deployment target be raised from 15.0 to 16.1 when Live Activities ship? Or keep 15.0 with `#available` guards? (Recommend: keep 15.0, use `#available` guards)

2. **Dismissal policy default**: When HA sends `end_live_activity`, should the activity linger (`DismissalPolicy.default` — up to 4 hours showing final state) or dismiss immediately (`DismissalPolicy.immediate`)? Recommend exposing as optional `dismissal_policy` field in the end payload.

3. **iPad handling**: On iPad where `areActivitiesEnabled == false`, should the app send a webhook back to HA indicating the device doesn't support Live Activities? This would allow HA to suppress the notification option for iPad.

4. **Multiple servers**: If the user has multiple HA servers registered, should a `start_live_activity` push be scoped to the originating server via `webhook_id`? Recommend: yes, and the `webhook_id` check in the handler enforces this.

---

## Sources & References

### Cross-Platform Automation Example (Complete)

This single automation targets both Android 16+ and iOS 16.1+. On older Android it gracefully falls back to a standard notification; on iOS < 16.1 or iPad it falls back to a regular banner.

```yaml
# automation.yaml — washer cycle tracker (works on Android + iOS)
automation:
  - alias: "Washer Started"
    trigger:
      - platform: state
        entity_id: sensor.washer_state
        to: "running"
    action:
      - action: notify.mobile_app_<device>
        data:
          title: "Washing Machine"
          message: "Cycle in progress"
          data:
            tag: washer_cycle
            live_update: true                      # Android 16+
            live_activity: true                    # iOS 16.1+
            critical_text: "Running"               # Android: status bar chip. iOS: Dynamic Island compact
            progress: 0
            progress_max: 3600
            chronometer: true                      # show countdown timer
            when: 3600                             # seconds until done
            when_relative: true                    # treat as duration from now
            notification_icon: mdi:washing-machine
            notification_icon_color: "#2196F3"
            alert_once: true                       # Android: silent updates
            sticky: true                           # Android: non-dismissible
            visibility: public                     # Android: lock screen visible

  - alias: "Washer Progress Update"
    trigger:
      - platform: time_pattern
        minutes: "/5"
    condition:
      - condition: state
        entity_id: sensor.washer_state
        state: "running"
    action:
      - action: notify.mobile_app_<device>
        data:
          title: "Washing Machine"
          message: "{{ states('sensor.washer_remaining') }} remaining"
          data:
            tag: washer_cycle                      # same tag = update in-place on both platforms
            live_update: true
            live_activity: true
            critical_text: "{{ states('sensor.washer_remaining') }}"
            progress: "{{ state_attr('sensor.washer_remaining', 'elapsed_seconds') | int }}"
            progress_max: 3600
            chronometer: true
            when: "{{ state_attr('sensor.washer_remaining', 'remaining_seconds') | int }}"
            when_relative: true
            notification_icon: mdi:washing-machine
            notification_icon_color: "#2196F3"
            alert_once: true
            sticky: true
            visibility: public

  - alias: "Washer Done"
    trigger:
      - platform: state
        entity_id: sensor.washer_state
        to: "idle"
    action:
      - action: notify.mobile_app_<device>
        data:
          message: clear_notification              # same YAML on Android and iOS
          data:
            tag: washer_cycle
```

### Community

- Feature request discussion: https://github.com/orgs/home-assistant/discussions/84
- Android companion app (reference implementation): https://github.com/home-assistant/android
- Android Live Notifications blog post: https://automateit.lol/live-android-notifications/
- Reddit discussion: https://www.reddit.com/r/homeassistant/comments/1rw64n1/live_android_notifications/

### Internal References

- Notification command pattern: `Sources/Shared/Notifications/NotificationCommands/NotificationsCommandManager.swift`
- PushProvider architecture: `Sources/Extensions/PushProvider/PushProvider.swift`
- Existing widget entry: `Sources/Extensions/Widgets/Widgets.swift`
- Most recent complete new-feature example (Kiosk mode): `Sources/App/Kiosk/KioskSettings.swift`, `Sources/Shared/Database/Tables/KioskSettingsTable.swift`
- App registration payload: `Sources/Shared/API/HAAPI.swift` (`buildMobileAppRegistration`)
- Version gating pattern: `Sources/Shared/Environment/AppConstants.swift`
- Local push subscription: `Sources/Shared/Notifications/LocalPush/LocalPushManager.swift`
- `AppEnvironment` property-on-protocol pattern: `Sources/Shared/Notifications/Attachments/NotificationAttachmentManager.swift`
- Webhook send pattern (no new type): `Sources/Shared/API/Webhook/Networking/WebhookManager.swift`

### Apple Developer Documentation

- ActivityKit framework: https://developer.apple.com/documentation/activitykit
- `ActivityAttributes` protocol: https://developer.apple.com/documentation/activitykit/activityattributes
- Displaying Live Activities: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- Starting and updating with APNs: https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications
- `ActivityAuthorizationInfo`: https://developer.apple.com/documentation/activitykit/activityauthorizationinfo
- `ActivityAuthorizationError`: https://developer.apple.com/documentation/activitykit/activityauthorizationerror
- Human Interface Guidelines — Live Activities: https://developer.apple.com/design/human-interface-guidelines/live-activities
- WWDC23 — Meet ActivityKit: https://developer.apple.com/videos/play/wwdc2023/10184/
- WWDC23 — Update Live Activities with push notifications: https://developer.apple.com/videos/play/wwdc2023/10185/
- Previewing widgets and Live Activities in Xcode: https://developer.apple.com/documentation/widgetkit/previewing-widgets-and-live-activities-in-xcode
- APNs token-based auth: https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns

### External

- iOS 18 Live Activity rate limit changes: https://9to5mac.com/2024/08/31/live-activities-ios-18/
- Server-side Live Activities guide (Christian Selig): https://christianselig.com/2024/09/server-side-live-activities/
