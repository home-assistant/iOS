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

        let attributes = HALiveActivityAttributes(
            tag: tag,
            title: title,
            serverWebhookId: serverWebhookId,
            startedAt: Current.date().timeIntervalSince1970
        )
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
            if let existing = entries[tag] {
                // A duplicate for this tag survived from a previous run (Core re-sent a push-to-start
                // while the app was terminated). The snapshot order is arbitrary, so keep whichever
                // was started later by the server-stamped `startedAt` and end the other. Cancelling an
                // already-adopted loser's observation before ending it stops reportActivityDismissed(tag:)
                // from firing — Core keeps the survivor's token slot.
                guard startedLater(activity, than: existing.activity) else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    Current.Log.info("LiveActivityRegistry: ended older duplicate for tag \(tag) on reattach")
                    continue
                }
                existing.observationTask.cancel()
                await existing.activity.end(nil, dismissalPolicy: .immediate)
                entries[tag] = Entry(activity: activity, observationTask: makeObservationTask(for: activity))
                Current.Log.info(
                    "LiveActivityRegistry: replaced older duplicate for tag \(tag), keeping id=\(activity.id)"
                )
                continue
            }
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

            if let existing = entries[tag] {
                // Same activity we already track (e.g. one we started locally) — nothing to do.
                guard existing.activity.id != activity.id else { continue }

                // A different activity for a tag we already track: Core re-sent a push-to-start
                // because it had no per-activity token yet. Keep whichever was started later by the
                // server-stamped `startedAt` and end the other, so the survivor is deterministic
                // regardless of the order activityUpdates delivers a burst. Cancelling the loser's
                // observation before ending it stops its lifecycle handler from firing
                // reportActivityDismissed(tag:), which would drop the token slot the survivor repopulates.
                guard startedLater(activity, than: existing.activity) else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    Current.Log.info(
                        "LiveActivityRegistry: dropped older duplicate for tag \(tag), keeping existing id"
                    )
                    continue
                }
                existing.observationTask.cancel()
                await existing.activity.end(nil, dismissalPolicy: .immediate)
                Current.Log.info(
                    "LiveActivityRegistry: collapsed older duplicate for tag \(tag), keeping id=\(activity.id)"
                )
            }

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

    // MARK: - Private — Duplicate Resolution

    /// Whether `candidate` was started more recently than `current`, by the server-stamped
    /// `startedAt` (Unix epoch seconds). A missing timestamp sorts oldest; equal timestamps are
    /// not "later", so the incumbent is kept and needless duplicate churn is avoided.
    private func startedLater(
        _ candidate: Activity<HALiveActivityAttributes>,
        than current: Activity<HALiveActivityAttributes>
    ) -> Bool {
        (candidate.attributes.startedAt ?? 0) > (current.attributes.startedAt ?? 0)
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
            // Background session: the OS owns this upload and keeps retrying it (up to its 2 h
            // resource timeout) across connectivity changes even if the app is suspended or
            // terminated — so a momentary drop, or losing foreground time, doesn't lose the token.
            // Reliable token delivery is what lets Core flush the buffered update and stop sending
            // starts, so it should not be best-effort like sendEphemeral.
            Current.webhooks.sendPassive(server: server, request: request).cauterize()
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
#endif
