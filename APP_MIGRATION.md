# Moving the app to a new Apple Developer account

Apple's App Transfer is not available for this app, so the replacement ships as a **new app record,
under a new team, with a new bundle ID**. Both apps are on the App Store for a while, and users move
themselves across with the in-app migration flow (`Sources/App/Container/AppMigration`).

Everything below is ordered so the long-lead items (Apple entitlement approvals, Home Assistant core
changes) start before the work that depends on them.

---

## Task list — in the order to do them

Ordered by how quickly each one can be finished, not by how important it is. The first block is all
short: a decision, a form, a ticket. Several of those start a clock running somewhere else (Apple
approvals, a Home Assistant core PR, a DNS-level file you do not own), so getting them out of the
way on day one is what keeps the rest from stalling. Everything below this list is reference detail
for the same items.

### Block 1 — same day, minutes each, and they unblock everything else

- [ ] Decide the new bundle ID prefix, the App Store name (must differ from the current one while
      both apps exist) and the new URL scheme (must not be `homeassistant`). — §0
- [ ] File the Apple entitlement request for **critical alerts**. — §1.2 Group A
- [ ] File the Apple entitlement request for the **Network Extension / local push provider**
      (`app-push-provider`). — §1.2 Group A
- [ ] File the Apple entitlement request for **Thread network credentials**. — §1.2 Group A
- [ ] File the **CarPlay** entitlement request against the new main App ID (both driving-task and
      voice-based-conversation). — §1.2 Group A
- [ ] File the Apple entitlement request for **user-assigned device name**. — §1.2 Group A
- [ ] Open the Home Assistant core issue/PR to allow `app_id` in the `update_registration` webhook
      schema. **Blocks notifications after migration.** — §3.1
- [ ] Raise the request to add the new team + bundle ID to the `apple-app-site-association` files
      for `home-assistant.io`, `*.home-assistant.io` and `my.home-assistant.io`. Not your
      infrastructure, so start the conversation now. — §1.3
- [ ] Create the App Store Connect app record and reserve the name. — §1.4

### Block 2 — an afternoon, mechanical, no waiting on anyone

- [ ] Register the full family of bundle IDs: main app, `.APNSAttachmentService`,
      `.NotificationContentExtension`, `.Intents`, `.Widgets`, `.ShareExtension`, `.PushProvider`,
      `.Matter`, `.watchkitapp`, `.watchkitapp.WatchWidgets`, the Mac launcher. — §1.1
- [ ] Create the App Group `group.<prefix>.homeassistant` (and the `.dev` variant) and the keychain
      sharing group. — §1.1
- [ ] Enable the self-serve entitlements on the new identifiers: push, associated domains,
      HealthKit + background delivery, Siri, NFC, Wi-Fi info, communication notifications,
      time-sensitive notifications, App Group, keychain group. Watch the ones the **extensions** also
      need. — §1.2 Group B
- [ ] Create the new APNs auth key (`.p8`). — §1.1
- [ ] Set `BUNDLE_ID_PREFIX` and `DEVELOPMENT_TEAM` in `Configuration/HomeAssistant.xcconfig`. — §2.1
- [ ] Set `ENV_URL_HANDLER` (two places in the Xcode project, debug and release) to the new scheme.
      — §2.1
- [ ] Fill in the four placeholders in `AppMigrationConstants`: `destinationBundleID`,
      `destinationURLScheme`, `destinationAppStoreURL`, `destinationUniversalLinkBase`. The migration
      flow stays hidden until these are real. — §4
- [ ] Update `LSApplicationQueriesSchemes` in `Sources/App/Resources/Info.plist` to the real
      destination scheme (currently the `homeassistant-next` placeholder). — §4
- [ ] Rename the hard-coded identifiers: BGTaskScheduler IDs in `Info.plist`,
      `BackgroundRefreshManager.swift`, `RemindersSyncBackgroundRefresher.swift`,
      `WatchWidgetConstants.swift`, `CrashReporter.swift`, `LocalPushEvent.swift`,
      `complicationManifest.json`, `fastlane/lanes/testing.rb`. — §2.2
- [ ] Create the new Firebase apps and replace `GoogleService-Info-{Debug,Release}.plist`. — §2.2

### Block 3 — a day or more each, and they depend on Block 2

- [ ] Add `ENABLE_*_<NEWTEAMID> = 1` to the xcconfig for each Group A entitlement, as each approval
      lands. — §1.2 Group A
- [ ] Generate the new certificates and provisioning profiles in `match`; confirm the Catalyst
      profiles carry all eight sandbox entitlements. — §1.2 Group C, §2.3
- [ ] Create the new App Store Connect API key and update the CI secrets
      (`HOMEASSISTANT_APPLE_ID`, `HOMEASSISTANT_TEAM_ID`). — §2.3
- [ ] Add the new team's APNs key to the push relay and register the new bundle ID as a valid topic;
      keep serving the old `app_id` in parallel. — §3.2
- [ ] Once the Home Assistant core change lands: send `AppIdentifier` from
      `buildMobileAppUpdateRegistration()`, and decide the fallback for servers too old to accept it.
      — §3.1
- [ ] Teach the `my.home-assistant.io` redirect about the new URL scheme. — §3.3
- [ ] Record the reference images for the migration snapshot tests (the tests are written; the
      `Tests-App` host does not launch on every machine, so this may have to happen in CI). — §4
- [ ] Run the migration end to end on a device with two real builds. — §4
- [ ] Rebuild the App Store Connect metadata: privacy labels, export compliance, age rating,
      categories, screenshots, review notes explaining the account move. — §1.4

### Block 4 — release, in this order

- [ ] Ship the old app's migration update first and let it soak. — §6
- [ ] Submit the new app. — §6
- [ ] Publish the documentation, release notes and forum post about the move. — §6
- [ ] Rebuild the TestFlight groups on the new account. — §1.4
- [ ] Monitor support load on notifications, widgets and watch complications. — §6
- [ ] Later: ship a migration-only update to the old app, then remove it from sale. Keep the push
      relay serving the old `app_id` well past that point. — §7

---

## 0. Decisions to lock first

| Decision | Why it blocks work |
|---|---|
| New bundle ID prefix (`BUNDLE_ID_PREFIX`) | Cascades into every target ID, the App Group, the keychain group and `AppConstants.BundleID` |
| New App Store name | App names are unique across the App Store; the new record cannot reuse the current name while the old app exists |
| New URL scheme (`ENV_URL_HANDLER`) | Must differ from `homeassistant`, otherwise iOS picks an arbitrary winner while both apps are installed — see §4 |
| Whether the migration carries credentials | It currently does (users are not asked to sign in again). The alternative is re-login, which is simpler but loses the device registration |
| Whether the handoff uses a universal link or a custom scheme | A universal link needs a domain + `apple-app-site-association` under the new team; it is the only tamper-proof option (see §4) |

---

## 1. New Apple Developer account setup

### 1.1 Identifiers to register

The project derives every ID from `PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_ID_PREFIX}.HomeAssistant…`,
so register the whole family:

- `<prefix>.HomeAssistant` (main app)
- `.APNSAttachmentService`, `.NotificationContentExtension`, `.Intents`, `.Widgets`, `.ShareExtension`,
  `.PushProvider`, `.Matter`
- `.watchkitapp`, `.watchkitapp.WatchWidgets`
- The Mac launcher (`Sources/Launcher`) for the Catalyst build
- App Group `group.<prefix>.homeassistant` (+ `.dev` variant)
- Keychain sharing group `<prefix>.HomeAssistant`
- An APNs auth key (`.p8`) for the new team

### 1.2 Entitlements to request or re-enable

**Nothing carries over.** Every entitlement is granted per team and per App ID, so all of these have
to be obtained again on the new account, for the new bundle IDs. They fall into three groups by how
long they take.

#### Group A — needs an Apple request form and approval (start these first: days to weeks)

These are the long poles. They are not toggles in the Developer portal: you file a request, justify
the use case, and wait. All of them are injected at build time by
`Configuration/Entitlements/activate_special_entitlements.sh` and gated per team by
`ENABLE_*_<TEAMID>` in `Configuration/HomeAssistant.xcconfig` — add an `ENABLE_*_<NEWTEAMID> = 1`
line for each one granted.

- [ ] **`com.apple.developer.usernotifications.critical-alerts`** — critical notifications that
      bypass silent mode and Focus. Flag: `ENABLE_CRITICAL_ALERTS`.
      Without it: critical alerts arrive as ordinary notifications.
- [ ] **`com.apple.developer.networking.networkextension`** (value `app-push-provider`) — the local
      push provider (`Sources/Extensions/PushProvider`). Flag: `ENABLE_PUSH_PROVIDER`.
      Without it: local push stops working entirely.
- [ ] **`com.apple.developer.networking.manage-thread-network-credentials`** — reading Thread
      credentials to hand to Home Assistant. Flag: `ENABLE_THREAD_NETWORK_CREDENTIALS`.
      Without it: Thread credential sharing disappears.
- [ ] **`com.apple.developer.carplay-driving-task`** — the CarPlay scene (`Sources/CarPlay`).
      Flag: `ENABLE_CARPLAY`. Without it: no CarPlay app at all.
- [ ] **`com.apple.developer.carplay-voice-based-conversation`** — Assist in CarPlay.
      Flag: `ENABLE_CARPLAY`. Without it: no voice Assist in CarPlay.
- [ ] **`com.apple.developer.device-information.user-assigned-device-name`** — sending the user's
      device name to Home Assistant. Flag: `ENABLE_DEVICE_NAME`.
      Without it: the device shows a generic model name.

CarPlay approval is granted per App ID, not just per team — request it against the **new** main app
identifier. The others are per team.

#### Group B — self-serve on the new App ID (immediate, but easy to forget one)

Enable each of these on the new identifiers in the Developer portal. They live in
`Configuration/Entitlements/App-ios.entitlements` and `Extension-ios.entitlements`.

- [ ] **`aps-environment`** — push notifications. Needed on the extensions too, plus a **new APNs
      auth key** for the new team.
- [ ] **`com.apple.developer.associated-domains`** — `home-assistant.io`, `*.home-assistant.io`,
      `my.home-assistant.io`, and the migration universal link (§4). Main app only — but the AASA
      files are not yours to publish, see §1.3.
- [ ] **`com.apple.developer.healthkit`** — Health sensors. Main app only.
- [ ] **`com.apple.developer.healthkit.background-delivery`** — Health sensors in the background.
      Main app only.
- [ ] **`com.apple.developer.siri`** — Siri and App Intents. Main app only.
- [ ] **`com.apple.developer.nfc.readersession.formats`** (`TAG`) — NFC tag reading and writing.
      Main app only.
- [ ] **`com.apple.developer.networking.wifi-info`** — SSID-based internal/external URL switching.
      **Needed on the extensions too** — they declare it as well.
- [ ] **`com.apple.developer.usernotifications.communication`** — communication notifications.
      Main app only.
- [ ] **`com.apple.developer.usernotifications.time-sensitive`** — time-sensitive notifications.
      Main app only.
- [ ] **`com.apple.security.application-groups`** — `group.<prefix>.homeassistant`. Needed on the
      app, every extension, the watch app and the watch widgets.
- [ ] **`keychain-access-groups`** — server credentials shared across targets. Same set as above.

HealthKit is self-serve on the identifier but gets scrutiny at App Review — expect to justify it
again for a brand-new app record.

#### Group C — Mac Catalyst sandbox entitlements

No request needed, but they must be present in the new team's Mac provisioning profiles or the
Catalyst build breaks at runtime rather than at build time. From `App-catalyst.entitlements`,
`Extension-catalyst.entitlements` and `Launcher.entitlements`:

- [ ] `com.apple.security.app-sandbox`
- [ ] `com.apple.security.network.client`
- [ ] `com.apple.security.device.camera`
- [ ] `com.apple.security.device.audio-input`
- [ ] `com.apple.security.personal-information.location`
- [ ] `com.apple.security.personal-information.photos-library`
- [ ] `com.apple.security.files.user-selected.read-write`
- [ ] `com.apple.security.files.downloads.read-write`

#### Not an entitlement

- The Matter extension (`Sources/Extensions/Matter`) signs with the generic
  `Extension-ios.entitlements` and needs no Matter-specific entitlement — only the extension point.
- Background modes (`UIBackgroundModes`) and BGTaskScheduler identifiers are Info.plist entries, not
  entitlements; see §2.2 for the identifiers that need renaming.

### 1.3 Associated domains

`Configuration/Entitlements/App-ios.entitlements` claims `home-assistant.io`, `*.home-assistant.io`
and `my.home-assistant.io`. Those domains' `apple-app-site-association` files are served by Home
Assistant and must be updated to also list `<NEWTEAMID>.<prefix>.HomeAssistant`, or every My Home
Assistant link and universal link breaks in the new app. **This is a change on someone else's
infrastructure — raise it early.**

### 1.4 App Store Connect

- [ ] New app record (new SKU, new name, new App Store URL)
- [ ] Privacy nutrition labels, export compliance, age rating, categories — none of this carries over
- [ ] Screenshots and metadata (`fastlane/metadata`)
- [ ] TestFlight groups and testers rebuilt from scratch
- [ ] Ratings and reviews **do not transfer** — the new app starts at zero
- [ ] Review notes explaining that this is the same app under a new account, with a test server

---

## 2. Repo changes for the new app

### 2.1 Build configuration

- `Configuration/HomeAssistant.xcconfig`: `BUNDLE_ID_PREFIX`, `DEVELOPMENT_TEAM`, and the
  `ENABLE_*_<NEWTEAMID>` flags
- `HomeAssistant.xcodeproj`: `ENV_URL_HANDLER` (two places — debug and release) → the new scheme
- `Configuration/Entitlements/*.entitlements` need no edits: they interpolate `$(BUNDLE_ID_PREFIX)`
  and `$(AppIdentifierPrefix)` already

### 2.2 Hard-coded identifiers to change

Found by grepping `io.robbie`:

| File | What |
|---|---|
| `Sources/App/Resources/Info.plist` | `BGTaskSchedulerPermittedIdentifiers` (`…backgroundfetch`, `…reminderssync`), `LSApplicationQueriesSchemes` |
| `Sources/App/BackgroundRefreshManager.swift` | `taskIdentifier` |
| `Sources/App/Utilities/RemindersSync/RemindersSyncBackgroundRefresher.swift` | `taskIdentifier` |
| `Sources/WatchWidgets/WatchWidgetConstants.swift` | `defaultBundleID` |
| `Sources/Shared/Environment/CrashReporter.swift` | `guard AppConstants.BundleID.starts(with: "io.robbie.")` |
| `Sources/Shared/Notifications/LocalPush/LocalPushEvent.swift` | hard-coded `"app_id": "io.robbie.HomeAssistant"` — should be `AppConstants.BundleID` |
| `Sources/App/Resources/GoogleService-Info-{Debug,Release}.plist` | new Firebase apps |
| `Sources/App/Resources/gallery.ckcomplication/complicationManifest.json` | `client ID` |
| `fastlane/lanes/testing.rb`, `fastlane/Appfile`, `fastlane/Matchfile`, `fastlane/Deliverfile` | app identifier, team, match certificates |

Note: `AppConstants.BundleID` strips known target suffixes at runtime and `AppGroupID` is derived from
it, so the app group and keychain paths follow automatically once the prefix changes.

### 2.3 CI

- New signing certificates / provisioning profiles in `match`
- New App Store Connect API key for the upload lanes
- `HOMEASSISTANT_APPLE_ID` / `HOMEASSISTANT_TEAM_ID` secrets

---

## 3. Home Assistant side — ⚠️ one blocking item

### 3.1 `app_id` cannot currently be updated (blocker for notifications)

The migration hands the new app the **same webhook**, so Home Assistant keeps seeing one
`mobile_app` device and every automation targeting `notify.mobile_app_…` keeps working. But:

- `HomeAssistantAPI.buildMobileAppUpdateRegistration()` (`Sources/Shared/API/HAAPI.swift:673`) sends
  `app_data`, `app_version`, `device_name`, `manufacturer`, `model`, `os_version` — **not `app_id`**.
- Home Assistant's `update_registration` webhook schema does not accept `app_id` either.

So after a migration the server still believes the device is `io.robbie.HomeAssistant`, and the push
relay picks the APNs topic from that `app_id`. It would push the **old** app's topic with the **new**
app's device token, and APNs rejects it (`DeviceTokenNotForTopic`). **Notifications break.**

Required work, in order:

1. [ ] Home Assistant core PR: allow `app_id` in the `update_registration` schema
2. [ ] App change: include `AppIdentifier` in `buildMobileAppUpdateRegistration()`
3. [ ] Decide the fallback for servers too old to accept it (re-register, accepting a new device
       entity, or leave notifications broken until the user updates their server)

### 3.2 Push relay

`Sources/PushServer` routes by `app_id`. It needs:

- [ ] The new team's APNs auth key
- [ ] The new bundle ID registered as a valid topic
- [ ] Both app IDs served in parallel for the whole coexistence window

### 3.3 Frontend / My Home Assistant

- [ ] `my.home-assistant.io` redirect must learn the new URL scheme
- [ ] AASA updates from §1.3

---

## 4. The in-app migration

Implemented in `Sources/App/Container/AppMigration` and `Sources/Shared/Common/AppMigration`.
One codebase builds both apps; `AppMigrationRole` picks the side from the bundle ID.

**How it works.** The old app packages `ServerManager.restorableState()` (servers, connections and
tokens — the same encoding the watch is synced with) plus an `AppConfigurationTransfer` export
(widgets, watch, CarPlay, quick actions, kiosk, notification categories, NFC tags, reminders sync,
app settings). That is zlib-compressed, base64url-encoded and handed to the new app in a **URL
fragment**. The new app restores the servers first, then the configuration — that order matters,
because `AppConfigurationTransfer` drops anything pointing at a server it does not know. It then
opens a callback URL, and the old app retires itself (stops all location sources, shows a "you have
moved" screen). The old app never signs its servers out: that would delete the registration the new
app just inherited.

**What must still be filled in** — all placeholders live in `AppMigrationConstants`, and the flow
stays hidden until `AppMigrationConstants.isConfigured` returns `true`:

- [ ] `destinationBundleID`
- [ ] `destinationURLScheme` (and the matching entry in `Info.plist`'s `LSApplicationQueriesSchemes`,
      already added as `homeassistant-next`)
- [ ] `destinationAppStoreURL`
- [ ] `destinationUniversalLinkBase` — **strongly recommended.** With only a custom scheme, any app
      that registers the same scheme can intercept the handoff, and it carries refresh tokens. A
      universal link can only be claimed by the app the domain vouches for. The payload rides in the
      fragment, which is never sent to the server, so the Safari fallback leaks nothing.
- [ ] Set `ENV_URL_HANDLER` on the new app's build to `destinationURLScheme`

**Remaining work on the flow itself:**

- [x] Snapshot tests for the new screens — `Tests/App/Container/AppMigration`, 9 files / 17 cases
      covering both colour schemes
- [ ] Record the reference images for those tests (`record: true`, or delete `__Snapshots__` and run
      once). They cannot be recorded on a machine where the `Tests-App` host fails to bootstrap
- [ ] End-to-end test on device with two real builds
- [ ] Decide whether the old app should also refuse to run its web view once retired (today it only
      stops location and shows the notice in Settings)

---

## 5. What cannot be migrated (tell users)

iOS gives no app-to-app path for these; the flow says so up front on the explanation screen.

- Home Screen / Lock Screen / StandBy widgets and Control Center controls — must be re-added
- Apple Watch complications — must be re-added to the watch face; the old watch app must be deleted
- Shortcuts and automations in the Shortcuts app that call this app's App Intents — they point at the
  old app and have to be re-pointed
- Focus filters
- Notification permission, location permission and all other TCC grants — asked again
- `AppConstants.PermanentID` — regenerated (only used as notification metadata, low impact)

---

## 6. Release and coexistence

- [ ] Ship the old app's migration update **first**, and let it soak
- [ ] Publish the new app
- [ ] Both apps live: the old one prompts on launch (snoozed for 3 days per "not now") and keeps a
      permanent entry in Settings
- [ ] Documentation / release notes / forum post explaining the move
- [ ] Watch for support load around notifications, widgets and watch complications

---

## 7. Sunsetting the old app

- [ ] Old app update that is migration-only (no new features)
- [ ] Eventually remove the old app from sale — note that this does **not** uninstall it for anyone
- [ ] Keep the push relay serving the old `app_id` well past that point
