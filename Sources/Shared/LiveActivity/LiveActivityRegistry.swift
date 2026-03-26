#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// Stale date offset for all Live Activity content updates.
/// Activities are marked stale after 30 minutes if no further updates arrive.
private let kLiveActivityStaleInterval: TimeInterval = 30 * 60

@available(iOS 17.2, *)
public protocol LiveActivityRegistryProtocol: AnyObject {
    func startOrUpdate(tag: String, title: String, state: HALiveActivityAttributes.ContentState) async throws
    func end(tag: String, dismissalPolicy: ActivityUIDismissalPolicy) async
    func reattach() async
    func startObservingPushToStartToken() async
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
    static let webhookTypeToken = "mobile_app_live_activity_token"
    /// Keys in the token webhook request data dictionary.
    static let tokenWebhookKeys: Set<String> = ["activity_id", "push_token", "apns_environment"]

    /// Webhook type for reporting that a Live Activity was dismissed.
    static let webhookTypeDismissed = "mobile_app_live_activity_dismissed"
    /// Keys in the dismissed webhook request data dictionary.
    static let dismissedWebhookKeys: Set<String> = ["activity_id", "tag", "reason"]

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
    public func startOrUpdate(
        tag: String,
        title: String,
        state: HALiveActivityAttributes.ContentState
    ) async throws {
        // UPDATE path — activity already running with this tag
        if let existing = entries[tag] {
            let content = ActivityContent(
                state: state,
                staleDate: computeStaleDate(for: state)
            )
            await existing.activity.update(content)
            return
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
            return
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
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            cancelReservation(id: tag)
            Current.Log.info("LiveActivityRegistry: activities disabled on this device, skipping start for tag \(tag)")
            return
        }

        let attributes = HALiveActivityAttributes(tag: tag, title: title)
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

        // Immediately update with an AlertConfiguration to trigger the expanded Dynamic Island
        // presentation. Activity.request() only shows the compact view (small pill around the
        // camera cutout). The expanded "bloom" animation requires an update with an alert config.
        let alertContent = ActivityContent(
            state: state,
            staleDate: computeStaleDate(for: state),
            relevanceScore: 0.5
        )
        // iOS 26 SDK changed AlertConfiguration.sound from optional to non-optional.
        // Use .default so the expanded Dynamic Island "bloom" has a subtle alert sound.
        let alertConfig = AlertConfiguration(
            title: LocalizedStringResource(stringLiteral: title),
            body: LocalizedStringResource(stringLiteral: state.message),
            sound: .default
        )
        await activity.update(alertContent, alertConfiguration: alertConfig)

        let observationTask = makeObservationTask(for: activity)
        await confirmReservation(id: tag, entry: Entry(activity: activity, observationTask: observationTask))
        Current.Log.verbose("LiveActivityRegistry: started activity for tag \(tag), id=\(activity.id)")
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

    /// Re-attach observation tasks to any Live Activities that survived process termination.
    /// Call this at app launch before any notification handlers are invoked.
    public func reattach() async {
        for activity in Activity<HALiveActivityAttributes>.activities {
            let tag = activity.attributes.tag
            guard entries[tag] == nil else { continue }
            let observationTask = makeObservationTask(for: activity)
            entries[tag] = Entry(activity: activity, observationTask: observationTask)
            Current.Log.verbose("LiveActivityRegistry: reattached activity for tag \(tag), id=\(activity.id)")
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

    // MARK: - Public Helpers

    /// The stored push-to-start token for inclusion in registration payloads.
    /// Returns nil if the device hasn't received a token yet (pre-iOS 17.2 or not yet issued).
    public static var storedPushToStartToken: String? {
        AppConstants.Keychain[pushToStartTokenKeychainKey]
    }

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
                        await self.reportPushToken(tokenHex, activityID: activity.id)
                    }
                }

                // Observe activity lifecycle — clean up and notify HA when dismissed
                group.addTask {
                    for await state in activity.activityStateUpdates {
                        switch state {
                        case .dismissed, .ended:
                            await self.reportActivityDismissed(
                                activityID: activity.id,
                                tag: activity.attributes.tag,
                                reason: state == .dismissed ? "user_dismissed" : "ended"
                            )
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
    private func reportPushToken(_ tokenHex: String, activityID: String) async {
        let request = WebhookRequest(
            type: Self.webhookTypeToken,
            data: [
                "activity_id": activityID,
                "push_token": tokenHex,
                "apns_environment": Current.apnsEnvironment,
            ]
        )
        for server in Current.servers.all {
            Current.webhooks.sendEphemeral(server: server, request: request).cauterize()
        }
    }

    /// Notify HA servers that the Live Activity was dismissed or ended externally.
    /// This allows HA to stop sending APNs updates for this activity.
    private func reportActivityDismissed(activityID: String, tag: String, reason: String) async {
        let request = WebhookRequest(
            type: Self.webhookTypeDismissed,
            data: [
                "activity_id": activityID,
                "tag": tag,
                "reason": reason,
            ]
        )
        for server in Current.servers.all {
            Current.webhooks.sendEphemeral(server: server, request: request).cauterize()
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
}
#endif
