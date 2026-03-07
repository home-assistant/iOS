# Self-Hosted Push Notifications Plan

> **Goal**: Replace Nabu Casa's push relay with a self-hosted PushServer so the
> custom-built HA Companion app can receive push notifications without a
> subscription — while keeping the HA instance accessible remotely via
> Cloudflare Tunnel.

## Architecture

```
┌──────────────┐     HTTPS      ┌──────────────┐     APNs      ┌───────┐
│  Home        │ ──────────────▶│  PushServer  │ ─────────────▶│ Apple │
│  Assistant   │  push_url      │  (Vapor)     │  JWT Auth      │ APNs  │
│  10.1.64.41  │                │              │               │       │
└──────────────┘                └──────────────┘               └───┬───┘
                                                                   │
                                                                   ▼
                                                              ┌─────────┐
                                                              │ iPhone  │
                                                              │ App     │
                                                              └─────────┘
```

### How It Works Today (Nabu Casa)

1. HA fires `notify.mobile_app_*` → sends payload to
   `https://mobile-apps.home-assistant.io/api/sendPushNotification`
2. Nabu Casa's server forwards to Firebase Cloud Messaging (FCM)
3. FCM relays through Apple Push Notification service (APNs) to the iPhone

### How It Will Work (Self-Hosted)

1. HA fires `notify.mobile_app_*` → sends payload to **our PushServer**
2. PushServer authenticates directly with APNs using a JWT signed with our
   APNs Auth Key (.p8)
3. APNs delivers to the iPhone app (identified by our custom Bundle ID)
4. Firebase/FCM remains in the iOS app **only as a token broker** — it
   generates the device push token that APNs needs

The repo already contains a production-ready PushServer at
`Sources/PushServer/` — a Swift Vapor app with Dockerfile, rate limiting
(Redis or in-memory), and full APNs integration via the `APNSwift` library.

---

## Prerequisites

| Item | Where | Status |
|------|-------|--------|
| Apple Developer Account | developer.apple.com | ✅ Have it |
| Forked iOS repo | `mosed/TheConciergHap` | ✅ Done |
| Xcode 15.3+ | Local Mac | ▢ Verify |
| Firebase project (free tier) | console.firebase.google.com | ▢ Create |
| APNs Auth Key (.p8) | Apple Developer → Keys | ▢ Create |
| Cloudflare Tunnel (for remote HA access) | Lighthouse Docker | ▢ Set up |

---

## Implementation Steps

### Phase 1: Apple & Firebase Setup (External)

These steps happen outside of the codebase.

#### 1.1 — Create APNs Auth Key

1. Go to [Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Create a new key, enable **Apple Push Notifications service (APNs)**
3. Download the `.p8` file — **save it securely, Apple only lets you download it once**
4. Note down:
   - **Key ID** (10-char alphanumeric, e.g., `ABC1234DEF`)
   - **Team ID** (from Membership page, e.g., `XYZXYZXYZ0`)

#### 1.2 — Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project (e.g., `TheConciergHap`)
3. **Add an iOS app** with your chosen Bundle ID:
   - Bundle ID: `casa.choobfelfeli.TheConciergHap` *(or your preferred prefix)*
4. Download `GoogleService-Info.plist`
5. Optionally add a second iOS app for debug:
   - Bundle ID: `casa.choobfelfeli.TheConciergHap.dev`
   - Download its plist separately

> **Note**: Firebase is only used for device token management in the iOS app.
> Push delivery goes directly through APNs via PushServer, not through FCM.

---

### Phase 2: Fork Configuration (Code Changes)

#### 2.1 — Bundle ID Prefix

**File**: `Configuration/HomeAssistant.xcconfig`

```diff
- BUNDLE_ID_PREFIX = io.robbie
+ BUNDLE_ID_PREFIX = casa.choobfelfeli
```

This cascades to all targets (main app, extensions, widgets, watch app).

#### 2.2 — Development Team Override

**File**: `Configuration/HomeAssistant.overrides.xcconfig` *(create — gitignored)*

```xcconfig
DEVELOPMENT_TEAM = <YOUR_APPLE_TEAM_ID>
BUNDLE_ID_PREFIX = casa.choobfelfeli
```

#### 2.3 — Replace GoogleService-Info Plists

Replace all three files in `Sources/App/Resources/`:

| File | Bundle ID |
|------|-----------|
| `GoogleService-Info-Release.plist` | `casa.choobfelfeli.TheConciergHap` |
| `GoogleService-Info-Beta.plist` | `casa.choobfelfeli.TheConciergHap.beta` |
| `GoogleService-Info-Debug.plist` | `casa.choobfelfeli.TheConciergHap.dev` |

Download these from your Firebase project. The key fields that must match:
- `BUNDLE_ID` → your app's bundle identifier
- `GCM_SENDER_ID` → your Firebase project number
- `GOOGLE_APP_ID` → your Firebase app ID
- `PROJECT_ID` → your Firebase project ID

#### 2.4 — Push URL

**File**: `Sources/Shared/API/HAAPI.swift` (line ~552)

```diff
- "push_url": "https://mobile-apps.home-assistant.io/api/sendPushNotification",
+ "push_url": "https://<YOUR_PUSH_SERVER>/push/send",
```

The PushServer endpoint is `POST /push/send` as defined in
`Sources/PushServer/Sources/App/routes.swift`.

#### 2.5 — APNS Topic in PushServer

**File**: `Sources/PushServer/Sources/App/routes.swift` (line 9)

```diff
- let pushTopic = Environment.get("APNS_TOPIC") ?? "io.robbie.HomeAssistant"
+ let pushTopic = Environment.get("APNS_TOPIC") ?? "casa.choobfelfeli.TheConciergHap"
```

This is also configurable via the `APNS_TOPIC` environment variable, so the
code change is optional if you always set the env var.

---

### Phase 3: Deploy PushServer

#### Option A: Docker on Lighthouse (Recommended)

The PushServer has a ready-made Dockerfile at `Sources/PushServer/Dockerfile`.

Add to the existing TheConcierge `docker-compose.yml` on Lighthouse:

```yaml
  push-server:
    build:
      context: ./TheConciergHap/Sources/PushServer
      dockerfile: Dockerfile
    container_name: ha-push-server
    restart: unless-stopped
    ports:
      - "8090:8080"
    environment:
      - APNS_TOPIC=casa.choobfelfeli.TheConciergHap
      - APNS_KEY_IDENTIFIER=<YOUR_KEY_ID>
      - APNS_KEY_TEAM_IDENTIFIER=<YOUR_TEAM_ID>
      - APNS_KEY_CONTENTS=<CONTENTS_OF_P8_FILE>
      - LOG_LEVEL=info
    # Optional: add Redis for rate limiting
    # depends_on:
    #   - redis
    networks:
      - default
```

The PushServer will be accessible at `http://10.1.64.41:8090` internally.

For HA to reach it, since HA runs with `network_mode: host`, it can hit
`http://localhost:8090` or `http://10.1.64.41:8090` directly.

**push_url in the app**: If only used locally, point to the Cloudflare Tunnel
URL (e.g., `https://push.choobfelfeli.casa/push/send`). The push_url must be
reachable from the **HA server**, not the phone — HA is the one that calls it.

#### Option B: AWS Lambda + API Gateway

For a serverless approach using existing AWS infra:

1. Rewrite PushServer logic as a Python Lambda (simpler than deploying Swift)
2. Use `firebase-admin` SDK or direct APNs HTTP/2 calls
3. Front with API Gateway for HTTPS endpoint
4. Store APNs key in AWS Secrets Manager

This adds complexity. Option A is simpler since Lighthouse already runs Docker.

#### Option C: Fly.io

The repo includes `Sources/PushServer/app.fly.toml` — the upstream project
runs on Fly.io. This is viable but adds an external dependency.

**Recommendation**: Option A (Lighthouse Docker). No external services, no
cost, minimal latency since it's on the same host as HA.

---

### Phase 4: Build & Deploy iOS App

#### 4.1 — Install Dependencies

```bash
cd /Users/roadrunner/repos/choobfelfeli.casa/TheConciergHap
bundle install
bundle exec pod install --repo-update
```

#### 4.2 — Open in Xcode

```bash
open HomeAssistant.xcworkspace
```

#### 4.3 — Configure Signing

1. Select the `App-iOS` scheme
2. In Signing & Capabilities, select your Development Team
3. Xcode should auto-manage provisioning profiles
4. Ensure **Push Notifications** capability is enabled
5. Ensure **Background Modes** → Remote notifications is checked

#### 4.4 — Build & Run

- **Direct install**: Connect iPhone, build & run (⌘R)
- **TestFlight**: Archive → Upload to App Store Connect → TestFlight
  (90-day builds, renewable by re-uploading)
- **Ad Hoc**: Export with Ad Hoc provisioning (1-year validity)

**Recommendation**: TestFlight for convenience — auto-updates, no cable needed.

---

### Phase 5: Configure Home Assistant

After the app is installed and connected to HA:

1. Open the app, connect to your HA instance
2. The app registers with HA and provides its push token
3. HA stores the `push_url` from the app registration (pointing to your
   PushServer)
4. Test with Developer Tools → Services:

```yaml
service: notify.mobile_app_<your_device>
data:
  title: "Test Notification"
  message: "Push is working!"
```

---

## Security Considerations

- **APNs Auth Key**: Store the `.p8` contents as a Docker secret or
  environment variable. Never commit to git.
- **PushServer access**: The PushServer doesn't need to be internet-facing.
  HA calls it locally on Lighthouse. Only the Cloudflare Tunnel endpoint for
  HA itself needs internet exposure.
- **Rate limiting**: PushServer has built-in rate limiting. In-memory mode
  works for single-instance. Add Redis if you need persistence across restarts.

---

## Maintenance

| Task | Frequency | Effort |
|------|-----------|--------|
| Sync upstream (home-assistant/iOS) | Monthly or as needed | Low — push code rarely changes |
| TestFlight rebuild | Every 90 days | 5 min — archive & upload |
| APNs key renewal | Key doesn't expire | None |
| PushServer updates | Rare | Rebuild Docker image |

### Syncing Upstream

```bash
git fetch upstream
git merge upstream/main
# Resolve conflicts (typically only in xcconfig and GoogleService plists)
```

---

## Files Modified (Summary)

| File | Change |
|------|--------|
| `Configuration/HomeAssistant.xcconfig` | Bundle ID prefix |
| `Configuration/HomeAssistant.overrides.xcconfig` | Team ID (create, gitignored) |
| `Sources/App/Resources/GoogleService-Info-Release.plist` | Your Firebase config |
| `Sources/App/Resources/GoogleService-Info-Beta.plist` | Your Firebase config |
| `Sources/App/Resources/GoogleService-Info-Debug.plist` | Your Firebase config |
| `Sources/Shared/API/HAAPI.swift` | Push URL → your PushServer |
| `Sources/PushServer/Sources/App/routes.swift` | Default APNS_TOPIC (optional) |

---

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Push relay | Self-hosted PushServer (in-repo) | Already exists, production-tested, direct APNs |
| PushServer hosting | Lighthouse Docker | Same host as HA, zero cost, low latency |
| Firebase | Keep (token broker only) | App requires it for device token registration |
| Distribution | TestFlight | No cable needed, easy updates |
| Bundle ID prefix | `casa.choobfelfeli` | Matches domain, clean namespace |
| Remote HA access | Cloudflare Tunnel | Free, no ports exposed, no attack surface |
