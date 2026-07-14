---
name: ha-ios-push-live-activities
description: Live Activities and push notifications across the local-push and remote-push delivery flows. Use when implementing or fixing notifications, Live Activities, payload parsing/promotion, alerting behavior, or the SharedPush parser (including the vendored relay copy).
---

# Live Activities & Push Notifications

**When implementing or fixing anything related to Live Activities (or push notifications generally), always check BOTH delivery flows — local push and remote push.** They are handled by different code paths, so a field, behavior, or fix applied to one is easily missed in the other (e.g. a payload key parsed for APNs but dropped over local push, or alerting/sound handled differently per flow).

- **Remote push (APNs / cloud)**: Home Assistant → the push relay (`Sources/PushServer`) → APNs → the app / `Sources/Extensions/NotificationService`. The payload already carries a `homeassistant` dictionary.
- **Local push (WebSocket / `NEAppPushProvider`)**: delivered over the on-network channel and handled by `Sources/Extensions/PushProvider` + `Sources/Shared/Notifications/LocalPush` (`LocalPushManager`, `LocalPushEvent`). The payload arrives as a flat `{message, data}` shape and is reshaped by `LegacyNotificationParserImpl` (`Sources/SharedPush/Sources/NotificationParserLegacy.swift`), which must explicitly **promote** `data` fields into `homeassistant` — any field not in that promotion list is silently dropped on this flow only.

Both flows converge on `NotificationCommandManager` → `HandlerStartOrUpdateLiveActivity` → `LiveActivityRegistry` (`Sources/Shared/LiveActivity`), with the UI rendered by `Sources/Extensions/Widgets/LiveActivity`.

Practical checklist when changing this area:
- If you add or read a notification/Live-Activity payload field, confirm it survives **both** the local-push parser promotion list and the remote-push payload.
- Verify alerting behavior (sound, haptics, banner suppression, the `silent` flag) on **both** flows — local push presents notifications through `LocalPushManager`, not the system directly.
- `Sources/SharedPush` is vendored as a separate copy under `Sources/PushServer/SharedPush` (the relay). Keep the two parser copies in sync when a parsing change is relevant to **both** the app and the relay; some logic intentionally lives in only one copy (e.g. the Live Activity `live_update` promotion is app-only, since the relay/cloud path already carries a `homeassistant` dict). When you change one copy, decide explicitly whether the other needs the same change.
- Add/extend tests for both flows (e.g. `Tests/Shared/LocalPushManager.test.swift` for the local path, `Sources/PushServer/Tests/SharedPushTests` for the relay/parser).
