#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Foundation
import HAKit
import PromiseKit

/// Stale date offset for all Live Activity content updates.
/// Activities are marked stale after 30 minutes if no further updates arrive.
private let kLiveActivityStaleInterval: TimeInterval = 30 * 60

public protocol LiveActivityRegistryProtocol: AnyObject {
    @available(iOS 17.2, *)
    @discardableResult
    func startOrUpdate(
        tag: String,
        title: String,
        serverWebhookId: String?,
        state: HALiveActivityAttributes.ContentState
    ) async throws -> Bool
    @available(iOS 17.2, *)
    func end(tag: String, dismissalPolicy: ActivityUIDismissalPolicy) async
    @available(iOS 17.2, *)
    func reattach() async
    @available(iOS 17.2, *)
    func startObservingPushToStartToken() async
    @available(iOS 17.2, *)
    func startObservingRemoteActivityStarts() async
}

public extension LiveActivityRegistryProtocol {
    @available(iOS 17.2, *)
    func startObservingRemoteActivityStarts() async {}
}

/// Thread-safe registry for active `Activity<HALiveActivityAttributes>` instances.
///
/// Uses Swift's actor isolation to protect the `[String: Entry]` dictionary from
/// concurrent access by push handler queues, token observer tasks, and the main app.
///
/// The reservation pattern prevents TOCTOU races where two pushes with the same `tag`
/// arrive back-to-back before the first `Activity.request(...)` completes.
@available(iOS 17.2, *)
public actor LiveActivityRegistry: LiveActivityRegistryProtocol {
    // MARK: - Types

    struct Entry {
        let activity: Activity<HALiveActivityAttributes>
        let observationTask: Task<Void, Never>
    }

    // MARK: - Webhook Constants (wire-format frozen — tested in LiveActivityContractTests)

    /// Webhook type for reporting a new per-activity push token to HA.
    static let webhookTypeToken = "live_activity_token"
    /// Keys in the token webhook request data dictionary.
    static let tokenWebhookKeys: Set<String> = ["tag", "push_token", "expires_at"]
    /// ActivityKit limits Dynamic Island updates to 12 hours and Live Activities may persist longer; push tokens
    /// are given a 12-hour TTL to match the Dynamic Island cap.
    static let pushTokenTimeToLive: TimeInterval = 12 * 60 * 60

    /// Webhook type for reporting that a Live Activity was dismissed.
    static let webhookTypeDismissed = "live_activity_dismissed"
    /// Keys in the dismissed webhook request data dictionary.
    static let dismissedWebhookKeys: Set<String> = ["tag"]

    // MARK: - State

    /// Tags currently in-flight (reserved but not yet confirmed or cancelled).
    private var reserved: Set<String> = []

    /// Tags where `end()` arrived while still reserved — activity must be dismissed on confirm.
    private var cancelledReservations: Set<String> = []

    /// Latest state received for a tag while it was still reserved (in-flight start).
    /// Applied to the activity immediately after `confirmReservation` completes.
    private var pendingState: [String: HALiveActivityAttributes.ContentState] = [:]

    /// Confirmed, running Live Activities keyed by tag.
    private var entries: [String: Entry] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Reservation (internal — called within actor context)

    private func reserve(id: String) -> Bool {
        guard entries[id] == nil, !reserved.contains(id) else { return false }
        reserved.insert(id)
        return true
    }

    /// Confirm a reservation. If `end()` arrived while we were in-flight, immediately dismiss.
    /// If a newer state arrived while we were in-flight, apply it after confirming.
    private func confirmReservation(id: String, entry: Entry) async {
        reserved.remove(id)
        let pending = pendingState.removeValue(forKey: id)
        if cancelledReservations.remove(id) != nil {
            // end() was called before Activity.request() completed — dismiss immediately.
            entry.observationTask.cancel()
            await entry.activity.end(nil, dismissalPolicy: .immediate)
            return
        }
        entries[id] = entry
        if let latestState = pending {
            // A second push arrived while Activity.request() was in-flight — apply the newer state now.
            let content = ActivityContent(
                state: latestState,
                staleDate: computeStaleDate(for: latestState)
            )
            await entry.activity.update(content)
        }
    }

    private func cancelReservation(id: String) {
        reserved.remove(id)
        cancelledReservations.remove(id)
        pendingState.removeValue(forKey: id)
    }

    private func remove(id: String) -> Entry? {
        let entry = entries.removeValue(forKey: id)
        entry?.observationTask.cancel()
        return entry
    }

    // MARK: - Public API

    /// Start a new Live Activity for `tag`, or update the existing one if already running.
    @discardableResult
    public func startOrUpdate(
        tag: String,
        title: String,
        serverWebhookId: String?,
        state: HALiveActivityAttributes.ContentState
    ) async throws -> Bool {
        // UPDATE path — activity already running with this tag
        if let existing = entries[tag] {
            let content = ActivityContent(
                state: state,
                staleDate: computeStaleDate(for: state)
            )
            await existing.activity.update(content)
            return true
        }

        // Also check system list in case we lost track after crash/relaunch
        if let live = Activity<HALiveActivityAttributes>.activities
            .first(where: { $0.attributes.tag == tag }) {
            let content = ActivityContent(
                state: state,
                staleDate: computeStaleDate(for: state)
            )
            await live.update(content)
            let observationTask = makeObservationTask(for: live)
            entries[tag] = Entry(activity: live, observationTask: observationTask)
            return true
        }

        guard Current.isTestFlight else {
            Current.Log.info("LiveActivityRegistry: start gated to TestFlight, skipping tag \(tag)")
            return false
        }

        // START path — guard against duplicates with reservation
        guard reserve(id: tag) else {
            if reserved.contains(tag) {
                // Activity.request() is in-flight — save this state so confirmReservation applies it.
                pendingState[tag] = state
                Current.Log.info(
                    "LiveActivityRegistry: duplicate start for tag \(tag), will apply latest state on confirm"
                )
            }
            return true
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            cancelReservation(id: tag)
            Current.Log.info("LiveActivityRegistry: activities disabled on this device, skipping start for tag \(tag)")
            return false
        }

        let attributes = HALiveActivityAttributes(tag: tag, title: title, serverWebhookId: serverWebhookId)
        let activity: Activity<HALiveActivityAttributes>

        do {
            let content = ActivityContent(
                state: state,
                staleDate: computeStaleDate(for: state),
                relevanceScore: 0.5
            )
            activity = try Activity<HALiveActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
        } catch {
            cancelReservation(id: tag)
            throw error
        }

        let observationTask = makeObservationTask(for: activity)
        await confirmReservation(id: tag, entry: Entry(activity: activity, observationTask: observationTask))
        Current.Log.verbose("LiveActivityRegistry: started activity for tag \(tag), id=\(activity.id)")
        return true
    }

    /// End and dismiss the Live Activity for `tag`.
    public func end(tag: String, dismissalPolicy: ActivityUIDismissalPolicy = .immediate) async {
        if let existing = remove(id: tag) {
            await existing.activity.end(nil, dismissalPolicy: dismissalPolicy)
            Current.Log.verbose("LiveActivityRegistry: ended activity for tag \(tag)")
            return
        }

        // Tag is still being started (Activity.request in-flight) — mark it so confirmReservation
        // dismisses the activity immediately once the request completes.
        if reserved.contains(tag) {
            cancelledReservations.insert(tag)
            Current.Log
                .verbose("LiveActivityRegistry: end() received for in-flight tag \(tag), will dismiss on confirm")
            return
        }

        // Fallback: check system list in case we lost track
        if let live = Activity<HALiveActivityAttributes>.activities
            .first(where: { $0.attributes.tag == tag }) {
            await live.end(nil, dismissalPolicy: dismissalPolicy)
        }
    }

    /// Re-attach observation tasks to any Live Activities that survived process termination,
    /// then sync Core: release the push token for any activity Core still thinks is live but
    /// is no longer running (e.g. it ended during an app update, so its dismissal was never
    /// observed). Call this at app launch before any notification handlers are invoked.
    public func reattach() async {
        var runningTags: Set<String> = []
        for activity in Activity<HALiveActivityAttributes>.activities {
            let tag = activity.attributes.tag
            runningTags.insert(tag)
            guard entries[tag] == nil else { continue }
            let observationTask = makeObservationTask(for: activity)
            entries[tag] = Entry(activity: activity, observationTask: observationTask)
            Current.Log.verbose("LiveActivityRegistry: reattached activity for tag \(tag), id=\(activity.id)")
        }
        await releaseStaleTokens(runningTags: runningTags)
    }

    /// Tell Core to drop tokens for activities that are no longer running. Without this, an
    /// activity that ended while the app wasn't running (its `.dismissed` state unobserved)
    /// leaves Core pushing to a dead token until it expires (8 h).
    private func releaseStaleTokens(runningTags: Set<String>) async {
        let stale = reportedTokenTags().subtracting(runningTags)
        guard !stale.isEmpty else { return }
        Current.Log.verbose("LiveActivityRegistry: releasing \(stale.count) stale Live Activity token(s) at launch")
        for tag in stale {
            await reportActivityDismissed(tag: tag)
        }
    }

    /// Observe the push-to-start token stream for `HALiveActivityAttributes`.
    ///
    /// Push-to-start (iOS 17.2+) allows HA to start a Live Activity entirely via APNs
    /// without the app being in the foreground. This is best-effort (~50% success from
    /// terminated state) — the primary flow remains notification command → app starts activity.
    ///
    /// The token is stored in Keychain and reported to HA via registration update so the
    /// relay server can use it to send push-to-start APNs payloads.
    ///
    /// Call this once at app launch; the stream is infinite and self-managing.
    public func startObservingPushToStartToken() async {
        for await tokenData in Activity<HALiveActivityAttributes>.pushToStartTokenUpdates {
            let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
            Current.Log.verbose("LiveActivityRegistry: new push-to-start token")

            // Store in Keychain — this token is higher-value than a per-activity token
            // (it can start any new activity) so UserDefaults is intentionally avoided.
            AppConstants.Keychain[LiveActivityRegistry.pushToStartTokenKeychainKey] = tokenHex

            // Report to all HA servers via registration update so the token is available
            // in the HA device registry immediately.
            reportPushToStartToken(tokenHex)
        }
    }

    /// Observe activities started remotely by ActivityKit push-to-start notifications.
    ///
    /// When APNs starts a Live Activity without launching through the notification command
    /// handler, ActivityKit delivers the created activity through this stream. Attach our
    /// normal push-token and lifecycle observers so Core can receive the per-activity token.
    public func startObservingRemoteActivityStarts() async {
        for await activity in Activity<HALiveActivityAttributes>.activityUpdates {
            let tag = activity.attributes.tag
            guard entries[tag] == nil else { continue }

            let observationTask = makeObservationTask(for: activity)
            entries[tag] = Entry(activity: activity, observationTask: observationTask)
            Current.Log.verbose(
                "LiveActivityRegistry: observed remotely started activity for tag \(tag), id=\(activity.id)"
            )
        }
    }

    // MARK: - Public Helpers

    /// The stored push-to-start token for inclusion in registration payloads.
    /// Returns nil if the device hasn't received a token yet (pre-iOS 17.2 or not yet issued).
    public static var storedPushToStartToken: String? {
        AppConstants.Keychain[pushToStartTokenKeychainKey]
    }

    static let pushToStartRegistrationKey = "start_live_activity_token"
    static let pushToStartTokenKeychainKey = "live_activity_push_to_start_token"

    /// Registration key carrying how many seconds HA should wait for this device to report a
    /// Live Activity's push token before it may send another start for the same tag. Reported
    /// so HA need not hard-code the duration — the device owns it.
    static let startFailsafeRegistrationKey = "live_activity_start_failsafe"

    /// Value reported under `startFailsafeRegistrationKey`. Bounds how long HA suppresses
    /// duplicate starts, so a push-to-start that silently fails recovers afterwards. Kept below
    /// `pushTokenTimeToLive` since starting again is pointless once a token could no longer live,
    /// yet long enough to outlast a realistic offline period (e.g. a flight).
    static let startSuppressionTimeToLive: TimeInterval = 6 * 60 * 60

    // MARK: - Private — Stale Date

    /// Compute the appropriate stale date for a Live Activity content update.
    ///
    /// When a countdown timer is active, set staleDate = countdownEnd + 2 s so that:
    ///   1. The system marks the activity stale shortly after the timer reaches zero,
    ///      prompting HA to send a follow-up update.
    ///   2. staleDate is never exactly equal to countdownEnd — that causes the system
    ///      to show a spinner overlay on the lock screen presentation.
    ///
    /// For non-timer activities, fall back to the standard 30-minute freshness window.
    private func computeStaleDate(for state: HALiveActivityAttributes.ContentState) -> Date {
        if state.chronometer == true, let end = state.countdownEnd {
            // +2 s offset avoids staleDate == countdownEnd (system spinner bug).
            // max(..., now + 2) guards against a countdownEnd that is already in the past.
            return max(end.addingTimeInterval(2), Date().addingTimeInterval(2))
        }
        return Date().addingTimeInterval(kLiveActivityStaleInterval)
    }

    // MARK: - Private — Observation

    private func makeObservationTask(for activity: Activity<HALiveActivityAttributes>) -> Task<Void, Never> {
        Task {
            await withTaskGroup(of: Void.self) { group in
                // Observe push token updates — report each new token to all HA servers
                group.addTask {
                    for await tokenData in activity.pushTokenUpdates {
                        let tokenHex = tokenData.map { String(format: "%02x", $0) }.joined()
                        Current.Log.verbose(
                            "LiveActivityRegistry: new push token for tag \(activity.attributes.tag)"
                        )
                        await self.reportPushToken(tokenHex, tag: activity.attributes.tag)
                    }
                }

                // Observe activity lifecycle — clean up and notify HA when dismissed
                group.addTask {
                    for await state in activity.activityStateUpdates {
                        switch state {
                        case .dismissed, .ended:
                            await self.reportActivityDismissed(tag: activity.attributes.tag)
                            _ = await self.remove(id: activity.attributes.tag)
                            return
                        case .active, .stale:
                            break
                        case .pending:
                            // Activity has been requested but not yet displayed — no action needed.
                            break
                        @unknown default:
                            break
                        }
                    }
                }
            }
        }
    }

    // MARK: - Private — Webhook Reporting

    /// Report a new activity push token to all connected HA servers.
    /// The token is used by the relay server to send APNs updates directly to this activity.
    private func reportPushToken(_ tokenHex: String, tag: String) async {
        let expiresAt = Current.date()
            .addingTimeInterval(Self.pushTokenTimeToLive)
            .timeIntervalSince1970.rounded(.down)
        let request = WebhookRequest(
            type: Self.webhookTypeToken,
            data: [
                "tag": tag,
                "push_token": tokenHex,
                "expires_at": expiresAt,
            ]
        )
        for server in Current.servers.all {
            Current.webhooks.sendEphemeral(server: server, request: request).cauterize()
        }
        rememberReportedTokenTag(tag)
    }

    /// Notify HA servers that the Live Activity was dismissed or ended externally.
    /// This allows HA to stop sending APNs updates for this activity.
    private func reportActivityDismissed(tag: String) async {
        let request = WebhookRequest(
            type: Self.webhookTypeDismissed,
            data: [
                "tag": tag,
            ]
        )
        let sends = Current.servers.all.map { Current.webhooks.sendEphemeral(server: $0, request: request) }
        // Forget the tag only once every server confirms the release. If any send fails (e.g. the
        // device is offline when the activity ends), keep it so reattach() retries on next launch.
        when(fulfilled: sends).done { [weak self] in
            Task { await self?.forgetReportedTokenTag(tag) }
        }.catch { error in
            Current.Log.verbose("LiveActivityRegistry: dismiss not confirmed for tag \(tag), will retry: \(error)")
        }
    }

    /// Report the push-to-start token to all HA servers via registration update.
    /// HA stores this alongside the FCM push token in the device registry.
    /// Fire-and-forget: errors are logged but do not block the token observation loop.
    private func reportPushToStartToken(_ tokenHex: String) {
        for api in Current.apis {
            api.updateRegistration().catch { error in
                Current.Log.error("LiveActivityRegistry: failed to report push-to-start token: \(error)")
            }
        }
    }

    // MARK: - Private — Reported-token bookkeeping (App Group)

    /// Tags we currently hold a per-activity push token for in Core. Persisted across launches
    /// so `reattach()` can release tokens for activities that ended while the app wasn't running.
    private static let reportedTokenTagsKey = "liveActivityReportedTokenTags"

    private func reportedTokenTags() -> Set<String> {
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return [] }
        return Set(defaults.stringArray(forKey: Self.reportedTokenTagsKey) ?? [])
    }

    private func rememberReportedTokenTag(_ tag: String) {
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        var tags = Set(defaults.stringArray(forKey: Self.reportedTokenTagsKey) ?? [])
        guard tags.insert(tag).inserted else { return }
        defaults.set(Array(tags), forKey: Self.reportedTokenTagsKey)
    }

    private func forgetReportedTokenTag(_ tag: String) {
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        var tags = Set(defaults.stringArray(forKey: Self.reportedTokenTagsKey) ?? [])
        guard tags.remove(tag) != nil else { return }
        defaults.set(Array(tags), forKey: Self.reportedTokenTagsKey)
    }
}

/// Cross-process hand-off for ending Live Activities. The PushProvider extension has
/// no working ActivityKit, so it enqueues a tag and posts a Darwin signal; the app
/// drains the queue and ends the activity. The persisted queue is the durable path —
/// Darwin does not wake a suspended app, so the app also drains at launch/foreground.
enum LiveActivityPendingEnd {
    // Namespaced by App Group id so dev/beta/release installs never cross-signal.
    static var darwinNotificationName: String {
        AppConstants.AppGroupID + ".liveActivityPendingEnd"
    }

    private static let storeKey = "liveActivityPendingEndTags"
    private static let lock = NSLock()

    static func append(tag: String) {
        guard isValidTag(tag) else {
            Current.Log.error("LiveActivityPendingEnd: rejected invalid tag '\(tag)'")
            return
        }
        // A newer end supersedes a stale start queued earlier for the same tag. Done before
        // taking our lock so the two queues are never held simultaneously (no lock-order inversion).
        if #available(iOS 17.2, *) {
            LiveActivityPendingStart.remove(tag: tag)
        }
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        var tags = Set(defaults.stringArray(forKey: storeKey) ?? [])
        tags.insert(tag)
        defaults.set(Array(tags), forKey: storeKey)
        Current.Log.verbose("LiveActivityPendingEnd: enqueued '\(tag)', pending=\(tags.count)")
    }

    /// Remove a queued end for `tag` (called when a newer start is enqueued for the same tag).
    static func remove(tag: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        var tags = Set(defaults.stringArray(forKey: storeKey) ?? [])
        guard tags.remove(tag) != nil else { return }
        if tags.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            defaults.set(Array(tags), forKey: storeKey)
        }
    }

    static func drainAll() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return [] }
        let observed = Set(defaults.stringArray(forKey: storeKey) ?? [])
        guard !observed.isEmpty else { return [] }
        // Subtract only what we read, so a concurrent extension append isn't clobbered.
        let remaining = Set(defaults.stringArray(forKey: storeKey) ?? []).subtracting(observed)
        if remaining.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            defaults.set(Array(remaining), forKey: storeKey)
        }
        return Array(observed)
    }

    // Payload-less wake; the tags travel via the App Group store above.
    static func postDarwinSignal() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: darwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }

    // Mirrors HandlerStartOrUpdateLiveActivity.isValidTag.
    static func isValidTag(_ tag: String) -> Bool {
        guard !tag.isEmpty, tag.count <= 64 else { return false }
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        )
        return tag.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

/// Cross-process hand-off for starting/updating Live Activities. The PushProvider extension
/// has no working ActivityKit, so when a `live_update` notification arrives over the local-push
/// channel it serializes the request and posts a Darwin signal; the app drains the queue and
/// calls `startOrUpdate`. Mirrors `LiveActivityPendingEnd`. The persisted queue is the durable
/// path — Darwin does not wake a suspended app, so the app also drains at launch/foreground.
///
/// ⚠️ A start delivered via local push while the app is suspended therefore only materializes
/// when the app is next active — not in real time. Real-time background starts require APNs
/// push-to-start, which the registry already supports.
@available(iOS 17.2, *)
enum LiveActivityPendingStart {
    /// A serialized start/update request mirroring the arguments of `startOrUpdate`.
    struct Request: Codable {
        let tag: String
        let title: String
        let serverWebhookId: String?
        let state: HALiveActivityAttributes.ContentState
        let confirmID: String?
    }

    static func confirmLocalPushDelivery(for request: Request) {
        guard let confirmID = request.confirmID, let webhookID = request.serverWebhookId else { return }
        guard let server = Current.servers.all.first(where: { $0.info.connection.webhookID == webhookID }),
              let api = Current.api(for: server) else {
            Current.Log.error("LiveActivityPendingStart: no server for webhook to confirm local push delivery")
            return
        }
        Current.Log.verbose("LiveActivityPendingStart: confirming local push delivery for tag \(request.tag)")
        api.connection.send(.localPushConfirm(webhookID: webhookID, confirmID: confirmID)).promise.cauterize()
    }

    // Namespaced by App Group id so dev/beta/release installs never cross-signal.
    static var darwinNotificationName: String {
        AppConstants.AppGroupID + ".liveActivityPendingStart"
    }

    private static let storeKey = "liveActivityPendingStartRequests"
    private static let lock = NSLock()

    /// Enqueue a start/update request. Coalesces by tag (the latest state for a tag wins, so a
    /// burst of updates collapses to the freshest) and cancels any end queued earlier for the
    /// same tag — last writer wins.
    static func append(_ request: Request) {
        guard LiveActivityPendingEnd.isValidTag(request.tag) else {
            Current.Log.error("LiveActivityPendingStart: rejected invalid tag '\(request.tag)'")
            return
        }
        // A newer start supersedes a stale end queued earlier. Done before taking our lock so the
        // two queues are never held simultaneously (no lock-order inversion).
        LiveActivityPendingEnd.remove(tag: request.tag)
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        var requests = load(from: defaults).filter { $0.tag != request.tag }
        requests.append(request)
        store(requests, to: defaults)
        Current.Log.verbose("LiveActivityPendingStart: enqueued '\(request.tag)', pending=\(requests.count)")
    }

    /// Remove a queued start for `tag` (called when a newer end is enqueued for the same tag).
    static func remove(tag: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        let requests = load(from: defaults)
        let remaining = requests.filter { $0.tag != tag }
        guard remaining.count != requests.count else { return }
        if remaining.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            store(remaining, to: defaults)
        }
    }

    static func drainAll() -> [Request] {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return [] }
        let observed = load(from: defaults)
        guard !observed.isEmpty else { return [] }
        // Subtract only the tags we read, so a concurrent extension append of a different tag
        // isn't clobbered (mirrors LiveActivityPendingEnd.drainAll).
        let observedTags = Set(observed.map(\.tag))
        let remaining = load(from: defaults).filter { !observedTags.contains($0.tag) }
        if remaining.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            store(remaining, to: defaults)
        }
        return observed
    }

    // Payload-less wake; the requests travel via the App Group store above.
    static func postDarwinSignal() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: darwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }

    private static func load(from defaults: UserDefaults) -> [Request] {
        guard let data = defaults.data(forKey: storeKey) else { return [] }
        do {
            return try JSONDecoder().decode([Request].self, from: data)
        } catch {
            Current.Log.error("LiveActivityPendingStart: failed to decode queue, dropping it: \(error)")
            defaults.removeObject(forKey: storeKey)
            return []
        }
    }

    private static func store(_ requests: [Request], to defaults: UserDefaults) {
        do {
            let data = try JSONEncoder().encode(requests)
            defaults.set(data, forKey: storeKey)
        } catch {
            Current.Log.error("LiveActivityPendingStart: failed to encode queue: \(error)")
        }
    }
}

/// App-side drain for `LiveActivityPendingEnd`. Retain one instance to keep the Darwin
/// observer registered.
@available(iOS 17.2, *)
public final class LiveActivityPendingEndObserver {
    public init() {
        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            // C callback can't capture self; re-derive it (see DeviceWrapperBatteryObserver).
            guard let observer else { return }
            Unmanaged<LiveActivityPendingEndObserver>.fromOpaque(observer)
                .takeUnretainedValue()
                .drain()
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            callback,
            LiveActivityPendingEnd.darwinNotificationName as CFString,
            nil,
            .coalesce
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            nil,
            nil
        )
    }

    public func drain() {
        Self.drain()
    }

    public static func drain() {
        let tags = LiveActivityPendingEnd.drainAll()
        guard !tags.isEmpty else { return }
        Current.Log.verbose("LiveActivityPendingEnd: draining \(tags.count) tag(s) in app")
        // Background task so the async dismissal finishes even when backgrounded.
        _ = Current.backgroundTask(withName: "live-activity-pending-end") { _ in
            Promise<Void> { seal in
                Task {
                    for tag in tags {
                        await Current.liveActivityRegistry?.end(tag: tag, dismissalPolicy: .immediate)
                    }
                    DispatchQueue.main.async { seal.fulfill(()) }
                }
            }
        }
    }
}

/// App-side drain for `LiveActivityPendingStart`. Retain one instance to keep the Darwin
/// observer registered.
@available(iOS 17.2, *)
public final class LiveActivityPendingStartObserver {
    public init() {
        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            // C callback can't capture self; re-derive it (see DeviceWrapperBatteryObserver).
            guard let observer else { return }
            Unmanaged<LiveActivityPendingStartObserver>.fromOpaque(observer)
                .takeUnretainedValue()
                .drain()
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            callback,
            LiveActivityPendingStart.darwinNotificationName as CFString,
            nil,
            .coalesce
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            nil,
            nil
        )
    }

    public func drain() {
        Self.drain()
    }

    public static func drain() {
        let requests = LiveActivityPendingStart.drainAll()
        guard !requests.isEmpty else { return }
        Current.Log.verbose("LiveActivityPendingStart: draining \(requests.count) request(s) in app")
        // Background task so the async start/update finishes even when backgrounded.
        _ = Current.backgroundTask(withName: "live-activity-pending-start") { _ in
            Promise<Void> { seal in
                Task {
                    for request in requests {
                        do {
                            let presented = try await Current.liveActivityRegistry?.startOrUpdate(
                                tag: request.tag,
                                title: request.title,
                                serverWebhookId: request.serverWebhookId,
                                state: request.state
                            )
                            if presented == true {
                                LiveActivityPendingStart.confirmLocalPushDelivery(for: request)
                            }
                        } catch {
                            Current.Log.error(
                                "LiveActivityPendingStart: startOrUpdate failed for tag \(request.tag): \(error)"
                            )
                        }
                    }
                    DispatchQueue.main.async { seal.fulfill(()) }
                }
            }
        }
    }
}
#endif
