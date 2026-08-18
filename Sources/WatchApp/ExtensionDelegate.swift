import CryptoKit
import PromiseKit
import Shared
import UIKit
import UserNotifications
import WatchKit
import WidgetKit
import XCGLogger

class ExtensionDelegate: NSObject, WKApplicationDelegate {
    // MARK: Fileprivate

    fileprivate var watchConnectivityBackgroundPromise: Guarantee<Void>
    fileprivate var watchConnectivityBackgroundSeal: (()) -> Void
    fileprivate var watchConnectivityWatchdogTimer: Timer?

    private var immediateCommunicatorService: ImmediateCommunicatorService?
    /// Held for the app's lifetime — see `observeLegacyComplicationRenders`.
    private var legacyComplicationRenderToken: NSObjectProtocol?

    override init() {
        (self.watchConnectivityBackgroundPromise, self.watchConnectivityBackgroundSeal) = Guarantee<Void>.pending()
        super.init()
    }

    // MARK: - WKApplicationDelegate -

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.

        Current.Log.verbose("didFinishLaunching")

        // A background cold launch (background refresh, WCSession delivery) never fires
        // `applicationDidEnterBackground`, so without this the suspension machinery stays disarmed
        // and every database access runs unprotected — GRDB work still in flight when the process
        // freezes was the remaining 0xdead10cc crash cluster. Arming it here routes those accesses
        // through the expiring-activity protection; a later foreground transition resumes as usual.
        if WKApplication.shared().applicationState == .background {
            AppDatabaseSuspension.suspend()
        }

        // Import any legacy Realm data into GRDB before anything reads it
        RealmToGRDBMigration.migrateIfNeeded()

        UNUserNotificationCenter.current().delegate = self

        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert, .providesAppNotificationSettings]

        // No `registerForRemoteNotifications()` here: the watch target carries no `aps-environment`
        // entitlement (see Configuration/Entitlements/WatchApp.entitlements), so registration could
        // only ever fail with "no valid aps-environment entitlement string found for application" on
        // every launch. Notifications reach the watch forwarded from the paired iPhone.

        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            Current.Log.verbose("Requested notifications access \(granted), \(String(describing: error))")
        }

        setupWatchCommunicator()
        WatchWidgetComplicationSnapshotStore.update()
        observeLegacyComplicationRenders()

        // Re-apply any watch-local "Always use" URL choices to the persisted servers (their
        // connection info doesn't carry the override across launches/syncs).
        WatchServerSync.applyURLOverrides()

        // schedule the next background refresh
        Current.backgroundRefreshScheduler.schedule().cauterize()
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
        // If the application was previously in the background, optionally refresh the user interface.

        Current.Log.verbose("didBecomeActive")
        // watchOS can leave `WCSession.isReachable` stale across a suspend→resume (no
        // sessionReachabilityDidChange fires), which is why the app looked "unreachable" until a
        // restart. Re-read and re-broadcast the live value so reachability recovers on foreground.
        Communicator.shared.refreshConnectivityState()
        HomeAssistantAPI.syncWatchContext()
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state.
        // This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message)
        // or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        Current.Log.verbose("willResignActive")
        HomeAssistantAPI.syncWatchContext()
        Current.backgroundRefreshScheduler.schedule().cauterize()
    }

    func applicationWillEnterForeground() {
        AppDatabaseSuspension.resume()
    }

    func applicationDidEnterBackground() {
        // Suspend GRDB so a write can't be caught holding the app-group SQLite lock when the system
        // suspends the process — that termination (0xdead10cc) was the watch app's top crash cluster.
        AppDatabaseSuspension.suspend()
    }

    /// Runs database work delivered while the app may be backgrounded/suspending (WCSession callbacks)
    /// inside an expiring background activity, so the system keeps the process alive for the write
    /// instead of suspending it mid-commit (0xdead10cc). If the activity expires, GRDB is re-suspended,
    /// which aborts the in-flight write and releases the file lock.
    ///
    /// The claim is refcounted because these callbacks arrive in bursts — the phone can deliver several
    /// mirror blobs within milliseconds, and each gets its own activity. Suspension is process-wide, so
    /// without the refcount the first block to finish would abort the writes still running behind it.
    ///
    /// `work` reports whether it succeeded; `completion` runs on the main queue only for a successful
    /// run, so callers don't publish side effects for a write that rolled back.
    private static func performProtectedDatabaseWork(
        reason: String,
        _ work: @escaping () -> Bool,
        completion: (() -> Void)? = nil
    ) {
        ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
            if expired {
                // Nothing was claimed on this path, so only suspend if no sibling is mid-write.
                AppDatabaseSuspension.suspendIfIdle()
                return
            }
            AppDatabaseSuspension.beginProtectedAccess()
            let didSucceed = work()
            DispatchQueue.main.async {
                // Re-suspend when this was the last access in flight and we're still backgrounded;
                // harmless when active (any `Current.database()` access resumes it again).
                AppDatabaseSuspension.endProtectedAccess(
                    suspend: WKApplication.shared().applicationState == .background
                )
                guard didSucceed else { return }
                completion?()
            }
        }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        HomeAssistantAPI.syncWatchContext()

        // Sent when the system needs to launch the application in the background to process tasks.
        // Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                Current.Log.verbose("WKApplicationRefreshBackgroundTask received")

                // The system watchdog kills the app if this task isn't completed within its
                // wall-clock budget: 15s when warm, 25s when cold-launched for the refresh
                // (CSLHandleBackgroundRefreshAction transgression). The refresh work below talks
                // to the network with timeouts larger than that budget, so completing "when done"
                // isn't enough — always complete at a hard deadline, even mid-work. Both paths run
                // on the main queue (PromiseKit's default), so the flag needs no synchronization.
                var didComplete = false
                let completeTask = {
                    guard !didComplete else { return }
                    didComplete = true
                    backgroundTask.setTaskCompletedWithSnapshot(false)
                }

                // Schedule the next refresh up front so a deadline hit can't skip it.
                Current.backgroundRefreshScheduler.schedule().cauterize()

                after(seconds: 10).done {
                    if !didComplete {
                        Current.Log.info("completing background refresh task at deadline; work still running")
                    }
                    completeTask()
                }

                firstly {
                    when(fulfilled: Current.apis.map { $0.updateComplications(passively: true) })
                }.then { _ -> Promise<Void> in
                    // Refresh the modern watch-rendered complications by fetching their live values
                    // directly over REST. This path doesn't need the paired iPhone, so a watch on its
                    // own network (e.g. LTE) still updates as long as the server is reachable.
                    Promise { seal in
                        Task {
                            await WatchWidgetComplicationSnapshotStore.refresh()
                            seal.fulfill(())
                        }
                    }
                }.ensure {
                    completeTask()
                }.cauterize()
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: Date.distantFuture,
                    userInfo: nil
                )
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                enqueueForCompletion(connectivityTask)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                Current.webhooks.handleBackground(for: urlSessionTask.sessionIdentifier) {
                    Current.backgroundRefreshScheduler.schedule().done {
                        urlSessionTask.setTaskCompletedWithSnapshot(false)
                    }
                }
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    func handle(_ userActivity: NSUserActivity) {
        if isAssistWidgetURL(userActivity.webpageURL) {
            launchAssist()
        } else {
            Current.Log.verbose("Unhandled user activity: \(userActivity.activityType)")
        }
    }

    private func launchAssist() {
        // Record the intent so a cold launch still opens Assist once the UI appears, and post the
        // notification for the case where the view is already on screen (warm launch).
        AssistDefaultComplication.pendingLaunch = true
        NotificationCenter.default.post(name: AssistDefaultComplication.launchNotification, object: nil)
    }

    private func isAssistWidgetURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        return ["homeassistant", "homeassistant-dev"].contains(url.scheme) && url.host == "assist"
    }

    func setupWatchCommunicator() {
        // This directly mutates the data structure for observations to avoid race conditions.

        Communicator.shared.state.observations.store[.init(queue: .main)] = { state in
            Current.Log.verbose("Activation state changed: \(state)")

            HomeAssistantAPI.syncWatchContext()
        }

        Communicator.shared.reachability.observations.store[.init(queue: .main)] = { reachability in
            Current.Log.verbose("Reachability changed: \(reachability)")
        }

        Communicator.shared.interactiveImmediateMessage.observations.store[.init(queue: .main)] = { message in
            Current.Log.verbose("Received message: \(message.identifier)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        immediateCommunicatorService = ImmediateCommunicatorService.shared

        Communicator.shared.immediateMessage.observations.store[.init(queue: .main)] = { [weak self] message in
            Current.Log.verbose("Received message: \(message.identifier)")
            self?.immediateCommunicatorService?.evaluateMessage(message)
            self?.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.guaranteedMessage.observations.store[.init(queue: .main)] = { [weak self] message in
            // Identifier and shape only. Interpolating the message itself dumped the whole payload —
            // tens of KB of serialized plist per config response, carrying the user's entity ids,
            // script names and server names — into a log file users attach to bug reports.
            Current.Log.verbose(
                "Received guaranteed message! \(message.identifier) (keys: \(message.content.keys.sorted()))"
            )

            if message.identifier == GuaranteedMessages.sync.rawValue {
                HomeAssistantAPI.syncWatchContext()
            }

            self?.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.blob.observations.store[.init(queue: .main)] = { [weak self] blob in
            Current.Log.verbose("Received blob: \(blob.identifier)")

            if blob.identifier == WatchDatabaseMirror.blobIdentifier {
                self?.applyPushedDatabaseMirror(blob.content, metadata: blob.metadata)
            }

            self?.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        // No context observer: complication data reaches the watch exclusively through the database
        // mirror (chunked pull + background transferFile push), which writes straight into GRDB —
        // the watch no longer decodes any JSON payloads. Older phones still send complications in
        // the application context; those keys are simply ignored.

        Communicator.shared.complicationInfo.observations.store[.init(queue: .main)] = { complicationInfo in
            // Count only — the payload carries user-identifying complication content (see above).
            Current.Log.verbose("Received complication info: \(complicationInfo.content.count) key(s)")

            self.updateComplications()
        }

        Communicator.shared.activate()
    }

    private func enqueueForCompletion(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        DispatchQueue.main.async { [self] in
            guard Communicator.shared.hasPendingDataToBeReceived else {
                // nothing else to be received
                task.setTaskCompletedWithSnapshot(false)
                return
            }

            // wait for it to send the next set of data
            watchConnectivityBackgroundPromise.done {
                task.setTaskCompletedWithSnapshot(false)
            }

            if watchConnectivityWatchdogTimer == nil || watchConnectivityWatchdogTimer?.isValid == false {
                // 10s should be more than enough time, and the system timer's at 15s (last tested watchOS 7)
                let timer = Timer.scheduledTimer(
                    withTimeInterval: 10.0,
                    repeats: true
                ) { [weak self] _ in
                    // we endeavor to not need this timer, but apple's api is so difficult to micromanage
                    // that it's just safer to guess and check every few seconds
                    Current.Log.info("ending background task due to our own watchdog timer")
                    // Force: data can stay "pending" indefinitely (e.g. a wedged file transfer), and
                    // holding the task past ~15s gets the app killed (CSLHandleBackgroundWCSessionAction
                    // transgression). The system delivers a new task when the data actually arrives.
                    self?.endWatchConnectivityBackgroundTaskIfNecessary(force: true)
                }

                watchConnectivityBackgroundPromise.done {
                    timer.invalidate()
                }

                watchConnectivityWatchdogTimer = timer
            }
        }
    }

    private func endWatchConnectivityBackgroundTaskIfNecessary(force: Bool = false) {
        DispatchQueue.main.async { [self] in
            guard force || !Communicator.shared.hasPendingDataToBeReceived else { return }

            // complete the current one
            watchConnectivityBackgroundSeal(())
            // and set up a new one for the next chain of updates
            (watchConnectivityBackgroundPromise, watchConnectivityBackgroundSeal) = Guarantee<Void>.pending()
        }
    }

    /// Serial queue the pushed-mirror decompress + decode runs on: the payload is a full reference
    /// mirror (hundreds of KB of plist), far too slow for the main queue the blob observation
    /// arrives on — decoding there at launch was a watchdog-kill crash cluster. Serial so burst
    /// deliveries decode in arrival order.
    private static let pushedMirrorQueue = DispatchQueue(label: "pushed-mirror-decode", qos: .utility)

    /// Apply a reference database mirror the iPhone pushed proactively over `transferFile` (arrives even
    /// when the watch app was suspended). Mirrors the watch-pull apply path so the watch's cached data
    /// (entities, areas, pipelines, complications) stays fresh without the user opening the app.
    private func applyPushedDatabaseMirror(_ data: Data, metadata: HAWatchConnectivity.Content?) {
        Self.pushedMirrorQueue.async { [weak self] in
            self?.decodeAndApplyPushedDatabaseMirror(data, metadata: metadata)
        }
    }

    private func decodeAndApplyPushedDatabaseMirror(_ data: Data, metadata: HAWatchConnectivity.Content?) {
        var data = data
        // Full-reference (v2) pushes travel compressed; the transfer metadata says so explicitly.
        if metadata?[WatchDatabaseMirror.compressedKey] as? Bool == true {
            do {
                data = try WatchDatabaseMirror.decompress(data)
            } catch {
                Current.Log.error("Failed to decompress pushed watch database mirror: \(error)")
                Current.clientEventStore.addEvent(.init(
                    text: "Failed to decompress pushed watch database mirror (\(data.count) bytes): \(error)",
                    type: .database
                ))
                return
            }
        }
        let mirror: WatchDatabaseMirror
        do {
            mirror = try WatchDatabaseMirror.decodeForWatchThrowing(data)
        } catch {
            Current.Log.error("Failed to decode pushed watch database mirror: \(error)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to decode pushed watch database mirror (\(data.count) bytes): \(error)",
                type: .database
            ))
            return
        }
        // Pushed mirrors typically arrive while the app is backgrounded — protect the write.
        Self.performProtectedDatabaseWork(reason: "watch-mirror-apply") {
            do {
                try mirror.apply()
                // The push carries the phone's digests in the transfer metadata; storing them for
                // the tables this push actually carried keeps the next interactive delta sync
                // accurate instead of re-fetching everything (or wrongly assuming it has data a
                // delta push omitted).
                WatchUserDefaults.shared.mergeDatabaseMirrorDigests(
                    metadata?[WatchDatabaseMirror.digestsKey] as? [String: String],
                    carrying: mirror.carriedDigestKeys
                )
                // The mirror also carries the servers. Applied here, inside the protected window,
                // for two reasons: restoring writes the Keychain mirror back through GRDB, and doing
                // it from the main-queue completion below blocked the main thread behind the burst
                // of mirror writes (the watch's watchdog-kill crash cluster) against a database the
                // expired activity may already have re-suspended.
                WatchServerSync.applyMirroredServersAndWait(mirror.servers)
                Current.Log.info("Applied pushed watch database mirror (\(data.count) bytes)")
                Current.clientEventStore.addEvent(.init(
                    text: "Applied pushed watch database mirror from iPhone (\(data.count) bytes)",
                    type: .database
                ))
                return true
            } catch {
                // `apply()` is one transaction, so a failure here left the database untouched. Report
                // it and skip the completion below rather than republishing the unchanged data.
                Current.Log.error("Failed to apply pushed watch database mirror: \(error)")
                Current.clientEventStore.addEvent(.init(
                    text: "Failed to apply pushed watch database mirror (\(data.count) bytes): \(error)",
                    type: .database
                ))
                return false
            }
        } completion: { [weak self] in
            // Rebuild complication snapshots and let the home screen re-render from the fresh data.
            WatchWidgetComplicationSnapshotStore.update()
            NotificationCenter.default.post(name: WatchComplicationConfig.didChangeNotification, object: nil)
            // The mirror is now the only complication delivery path, so it also reloads the ClockKit
            // timelines (previously done when the application context arrived).
            self?.updateComplications()
        }
    }

    /// Rebuild the WidgetKit snapshots whenever freshly rendered legacy complication templates land in
    /// the database. `WebhookResponseUpdateComplications` writes them from `Shared`, which can't reach
    /// the snapshot store in this target, so it announces the write and this picks it up — without it
    /// the new text sits in the database until the next periodic refresh happens to rebuild.
    private func observeLegacyComplicationRenders() {
        legacyComplicationRenderToken = NotificationCenter.default.addObserver(
            forName: WatchComplication.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            WatchWidgetComplicationSnapshotStore.update()
        }
    }

    private var isUpdatingComplications = false
    private func updateComplications() {
        // avoid double-updating due to e.g. complication info update request
        guard !isUpdatingComplications else { return }

        isUpdatingComplications = true

        firstly {
            when(fulfilled: Current.apis.map { $0.updateComplications(passively: true) })
        }.ensure { [self] in
            isUpdatingComplications = false
        }.ensure { [self] in
            WatchWidgetComplicationSnapshotStore.update()
            endWatchConnectivityBackgroundTaskIfNecessary()
        }.cauterize()
    }
}

extension ExtensionDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        #if DEBUG
        if response.actionIdentifier == NotificationSnoozeAction.debugTenSecondsActionIdentifier {
            Current.notificationDispatcher.reschedule(response.notification.request.content, after: 10)
            completionHandler()
            return
        }
        #endif

        // Snooze is an on-device-only convenience, mirroring NotificationManager on iOS: reschedule
        // a local re-delivery of the same notification on the watch (so it keeps its snooze actions)
        // instead of forwarding a notification action event to Home Assistant.
        if let minutes = NotificationSnoozeAction.minutes(fromActionIdentifier: response.actionIdentifier) {
            Current.notificationDispatcher.reschedule(
                response.notification.request.content,
                after: TimeInterval(minutes) * 60
            )
            completionHandler()
            return
        }

        guard let info = HomeAssistantAPI.PushActionInfo(response: response),
              let server = Current.servers.server(for: response.notification.request.content) else {
            completionHandler()
            return
        }

        firstly { () -> Promise<Void> in
            let (promise, seal) = Promise<Void>.pending()

            if Communicator.shared.currentReachability == .immediatelyReachable {
                Current.Log.info("sending via phone")
                Communicator.shared.send(.init(
                    identifier: InteractiveImmediateMessages.pushAction.rawValue,
                    content: ["PushActionInfo": info.toJSON(), "Server": server.identifier.rawValue],
                    reply: { message in
                        Current.Log.verbose("Received reply dictionary \(message)")
                        seal.fulfill(())
                    }
                ), errorHandler: { error in
                    Current.Log.error("Received error when sending immediate message \(error)")
                    seal.reject(error)
                })
            } else {
                Current.Log.info("sending via local")
                Current.api(for: server)?.handlePushAction(for: info)
                    .pipe(to: seal.resolve)
            }

            return promise
        }.ensure {
            completionHandler()
        }.cauterize()
    }
}

/// Result of refreshing a single modern complication, surfaced to the watch's on-device diagnostics
/// (the "Refresh complications" button in Settings).
struct ComplicationRefreshOutcome: Identifiable, Sendable {
    enum Status: String, Codable, Sendable {
        case live
        case cached
        case failed
    }

    let id: String
    let name: String
    let status: Status
    let reason: String?
    /// The entity backing the complication, when it has one — identifies exactly what was fetched.
    let entityId: String?
    /// The value now shown on the face: the freshly fetched value when live, the retained previous
    /// value when cached, nil when there's nothing to show.
    let value: String?
    /// How long this complication's fetch took.
    let duration: TimeInterval
}

/// Persisted record of a complication's last refresh attempt, shown on the watch's per-complication
/// diagnostics detail so the user can see when it last tried, whether it worked, and why not.
struct ComplicationRefreshRecord: Codable {
    let id: String
    let name: String
    let date: Date
    let status: ComplicationRefreshOutcome.Status
    let reason: String?
}

enum WatchWidgetComplicationSnapshotStore {
    static var kind: String {
        AppConstants.BundleID + ".watchkitapp.WatchWidgets"
    }

    static let defaultsKey = "watchWidgetComplicationSnapshots"
    static let recordsKey = "watchComplicationRefreshRecords"
    /// Fingerprint of the snapshot content this app last submitted to WidgetKit via
    /// `reloadAllTimelines`, kept separate from the store itself: the store can hold content the
    /// face was never re-rendered with (see `write`).
    private static let reloadFingerprintKey = "watchWidgetComplicationSnapshotsReloadFingerprint"
    /// Identity of the complication set the picker was last told about, so `recommendations()` is only
    /// re-queried when that set actually changed (see `invalidateRecommendationsIfNeeded`).
    private static let recommendationsIdentityKey = "watchWidgetComplicationRecommendationsIdentity"

    /// Fire-and-forget refresh for synchronous callers (launch, mirror receipt, home sync).
    static func update() {
        Task { await refresh() }
    }

    /// Write each server's self-fetch credential to the shared app group for the widget extension.
    private static func writeWidgetCredentials(to defaults: UserDefaults?) async {
        var credentials: [WatchWidgetServerCredential] = []
        for server in Current.servers.all {
            if let credential = await ComplicationStateFetcher.credential(for: server) {
                credentials.append(credential)
            }
        }
        WatchWidgetServerCredential.write(credentials, to: defaults)
    }

    /// Serializes `refresh()` so overlapping triggers share one run instead of racing.
    private actor RefreshCoordinator {
        static let shared = RefreshCoordinator()

        private var inFlight: Task<[ComplicationRefreshOutcome], Never>?

        /// Callers arriving while a refresh is running await that run rather than starting a competing
        /// one. Triggers land in bursts — one per pushed database mirror, plus the complication reload
        /// that follows each — and running them concurrently multiplies the REST round-trips (each on
        /// its own mTLS handshake) while they race to write the same snapshot list into the app group.
        func run(
            _ body: @escaping @Sendable () async -> [ComplicationRefreshOutcome]
        ) async -> [ComplicationRefreshOutcome] {
            if let inFlight {
                return await inFlight.value
            }
            let task = Task { await body() }
            inFlight = task
            let outcomes = await task.value
            inFlight = nil
            return outcomes
        }
    }

    /// Rebuilds every complication snapshot. Legacy complications render synchronously from their
    /// server-rendered data; modern configs fetch their live value directly from Home Assistant over
    /// REST — no paired iPhone required, so this also refreshes when the watch is on its own (e.g. on
    /// LTE), provided the server has a reachable URL. `async` so a background task can await it before
    /// completing (otherwise the app may be suspended before the REST fetch returns).
    ///
    /// Coalesced: concurrent callers join the run already in flight (see `RefreshCoordinator`).
    @discardableResult
    static func refresh() async -> [ComplicationRefreshOutcome] {
        await RefreshCoordinator.shared.run { await performRefresh() }
    }

    private static func performRefresh() async -> [ComplicationRefreshOutcome] {
        MaterialDesignIcons.register()
        let defaults = UserDefaults(suiteName: AppConstants.AppGroupID)

        // Hand the widget everything it needs to self-fetch on its own WidgetKit budget (so complications
        // stay fresh even when this WatchApp isn't woken). Best-effort; a missing credential just means the
        // widget keeps its last-known value until we write a fresh one.
        await writeWidgetCredentials(to: defaults)

        // GRDB is the single source of truth on the watch (populated by the background context and the
        // reload mirror). Legacy complications render synchronously from their server-rendered data.
        let legacy = ((try? WatchComplication.all()) ?? [])
            .map(WatchWidgetComplicationSnapshot.init(complication:))
        let configs = ((try? WatchComplicationConfig.all()) ?? [])

        // Last-known snapshots, keyed by id, so a failed refresh can keep showing the previous value
        // instead of blanking the complication.
        let previous = readSnapshots(defaults)

        // Write the synchronous set first so the face is never empty. Carry the last-known config
        // snapshots through so their live values aren't dropped while the async refresh runs.
        let cachedConfigSnapshots = configs.compactMap { previous[$0.id] }
        write(snapshots: [.placeholder, .assist] + legacy + cachedConfigSnapshots, defaults: defaults)

        guard !configs.isEmpty else { return [] }
        ComplicationRefreshDebugNotifier.notifyStarted(names: configs.map(\.displayName))
        let refreshStarted = Date()
        // Fetch every complication concurrently, and bound the whole gather. Serially, one slow or
        // unreachable server blocks the rest until its timeout; concurrently, a single slow build (a
        // custom-template complication chains several sequential template renders) could still hold
        // the write past the background task's ~10s deadline. Whatever hasn't answered by the deadline
        // falls back to its cached value, exactly like a failed fetch, so the complications that did
        // finish still refresh instead of the whole face freezing on one straggler.
        typealias Build = (
            index: Int,
            snapshot: WatchWidgetComplicationSnapshot,
            isLive: Bool,
            failureReason: String?,
            duration: TimeInterval
        )
        let gatherDeadline: TimeInterval = 8
        let builds: [Int: Build] = await withTaskGroup(of: Build?.self) { group in
            for (index, config) in configs.enumerated() {
                group.addTask {
                    let started = Date()
                    let result = await WatchWidgetComplicationSnapshot.make(config: config)
                    let duration = Date().timeIntervalSince(started)
                    return (index, result.snapshot, result.isLive, result.failureReason, duration)
                }
            }
            // Sentinel that returns nil once the budget is spent, so a stalled build can't hold the
            // gather open; cancelling the group then drops the stragglers' in-flight requests.
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(gatherDeadline * 1_000_000_000))
                return nil
            }
            var collected: [Int: Build] = [:]
            for await build in group {
                guard let build else { break }
                collected[build.index] = build
                if collected.count == configs.count {
                    break
                }
            }
            group.cancelAll()
            return collected
        }

        var configSnapshots: [WatchWidgetComplicationSnapshot] = []
        var outcomes: [ComplicationRefreshOutcome] = []
        for (index, config) in configs.enumerated() {
            let name = config.displayName
            let build = builds[index]
            if let build, build.isLive {
                configSnapshots.append(build.snapshot)
                outcomes.append(.init(
                    id: config.id,
                    name: name,
                    status: .live,
                    reason: nil,
                    entityId: config.entityId,
                    value: build.snapshot.title,
                    duration: build.duration
                ))
            } else if let cached = previous[config.id] {
                // Live fetch failed or didn't finish in time, but we have a previous value — keep it.
                let reason = build?.failureReason ?? "refresh did not finish in time"
                configSnapshots.append(cached)
                outcomes.append(.init(
                    id: config.id,
                    name: name,
                    status: .cached,
                    reason: reason,
                    entityId: config.entityId,
                    value: cached.title,
                    duration: build?.duration ?? 0
                ))
                Current.clientEventStore.addEvent(ClientEvent(
                    text: "Watch complication “\(name)” is showing a cached "
                        + "value; live refresh failed (\(reason))",
                    type: .backgroundOperation,
                    payload: ["complication": config.id, "reason": reason]
                ))
            } else if let build {
                // Nothing cached (e.g. just added) — show the name-only snapshot and record the error.
                configSnapshots.append(build.snapshot)
                outcomes.append(.init(
                    id: config.id,
                    name: name,
                    status: .failed,
                    reason: build.failureReason,
                    entityId: config.entityId,
                    value: nil,
                    duration: build.duration
                ))
                Current.clientEventStore.addEvent(ClientEvent(
                    text: "Watch complication “\(name)” "
                        + "could not load live data (\(build.failureReason ?? "unknown"))",
                    type: .networkRequest,
                    payload: ["complication": config.id, "reason": build.failureReason ?? "unknown"]
                ))
            }
            // Otherwise the build didn't finish in time and there's nothing cached (a just-added
            // complication) — leave it out this pass; the next refresh retries it.
        }
        write(snapshots: [.placeholder, .assist] + legacy + configSnapshots, defaults: defaults)
        persistRecords(outcomes, keepingIds: configs.map(\.id), defaults: defaults)
        let liveCount = outcomes.filter { $0.status == .live }.count
        let cachedCount = outcomes.filter { $0.status == .cached }.count
        let failedCount = outcomes.filter { $0.status == .failed }.count
        Current.clientEventStore.addEvent(ClientEvent(
            text: "Refreshed \(configs.count) watch complication(s): \(liveCount) live, "
                + "\(cachedCount) cached, \(failedCount) unavailable",
            type: .backgroundOperation,
            payload: ["live": liveCount, "cached": cachedCount, "failed": failedCount]
        ))
        ComplicationRefreshDebugNotifier.notifyFinished(
            outcomes,
            duration: Date().timeIntervalSince(refreshStarted)
        )
        return outcomes
    }

    /// Refresh a single complication (from its diagnostics detail's Retry button), leaving the others
    /// untouched. Updates that complication's stored snapshot and its refresh record, and returns the
    /// outcome so the detail can show the fresh result.
    @discardableResult
    static func refresh(configId: String) async -> ComplicationRefreshOutcome? {
        MaterialDesignIcons.register()
        let defaults = UserDefaults(suiteName: AppConstants.AppGroupID)
        let configs = (try? WatchComplicationConfig.all()) ?? []
        guard let config = configs.first(where: { $0.id == configId }) else { return nil }
        let name = config.displayName
        let previous = readSnapshots(defaults)
        let legacy = ((try? WatchComplication.all()) ?? [])
            .map(WatchWidgetComplicationSnapshot.init(complication:))

        ComplicationRefreshDebugNotifier.notifyStarted(names: [name])
        let fetchStarted = Date()
        let result = await WatchWidgetComplicationSnapshot.make(config: config)
        let duration = Date().timeIntervalSince(fetchStarted)
        let snapshot: WatchWidgetComplicationSnapshot
        let outcome: ComplicationRefreshOutcome
        if result.isLive {
            snapshot = result.snapshot
            outcome = .init(
                id: config.id,
                name: name,
                status: .live,
                reason: nil,
                entityId: config.entityId,
                value: result.snapshot.title,
                duration: duration
            )
        } else if let cached = previous[config.id] {
            snapshot = cached
            outcome = .init(
                id: config.id,
                name: name,
                status: .cached,
                reason: result.failureReason,
                entityId: config.entityId,
                value: cached.title,
                duration: duration
            )
        } else {
            snapshot = result.snapshot
            outcome = .init(
                id: config.id,
                name: name,
                status: .failed,
                reason: result.failureReason,
                entityId: config.entityId,
                value: nil,
                duration: duration
            )
        }

        // Rebuild the full set: keep every other complication's last snapshot, replace just this one.
        let configSnapshots: [WatchWidgetComplicationSnapshot] = configs.compactMap { other in
            other.id == config.id ? snapshot : previous[other.id]
        }
        write(snapshots: [.placeholder, .assist] + legacy + configSnapshots, defaults: defaults)
        persistRecords([outcome], keepingIds: configs.map(\.id), defaults: defaults)
        ComplicationRefreshDebugNotifier.notifyFinished([outcome], duration: duration)
        return outcome
    }

    /// The persisted per-complication refresh records, newest attempt per id.
    static func records() -> [String: ComplicationRefreshRecord] {
        readRecords(UserDefaults(suiteName: AppConstants.AppGroupID))
    }

    /// The last snapshot written for a complication. Used by the in-app complication row to render
    /// the known values immediately, before its own first live fetch answers.
    static func storedSnapshot(id: String) -> WatchWidgetComplicationSnapshot? {
        storedSnapshots()[id]
    }

    /// Every stored snapshot, keyed by complication id. The add flow's picker previews a whole list
    /// at once, so it reads the set once instead of decoding the payload per row.
    static func storedSnapshots() -> [String: WatchWidgetComplicationSnapshot] {
        readSnapshots(UserDefaults(suiteName: AppConstants.AppGroupID))
    }

    private static func persistRecords(
        _ outcomes: [ComplicationRefreshOutcome],
        keepingIds: [String],
        defaults: UserDefaults?
    ) {
        // Merge the fresh attempts into the stored records and drop any whose complication no longer
        // exists, so a targeted refresh only updates its own record.
        var stored = readRecords(defaults)
        let now = Date()
        for outcome in outcomes {
            stored[outcome.id] = ComplicationRefreshRecord(
                id: outcome.id,
                name: outcome.name,
                date: now,
                status: outcome.status,
                reason: outcome.reason
            )
        }
        stored = stored.filter { keepingIds.contains($0.key) }
        guard let defaults, let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: recordsKey)
    }

    private static func readRecords(_ defaults: UserDefaults?) -> [String: ComplicationRefreshRecord] {
        guard let defaults, let data = defaults.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([String: ComplicationRefreshRecord].self, from: data) else {
            return [:]
        }
        return records
    }

    private static func readSnapshots(_ defaults: UserDefaults?) -> [String: WatchWidgetComplicationSnapshot] {
        guard let defaults, let data = defaults.data(forKey: defaultsKey),
              let snapshots = try? JSONDecoder().decode([WatchWidgetComplicationSnapshot].self, from: data) else {
            return [:]
        }
        return Dictionary(snapshots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func write(snapshots: [WatchWidgetComplicationSnapshot], defaults: UserDefaults?) {
        guard let defaults else {
            Current.Log.error("Missing app group defaults for watch widget complication snapshots")
            return
        }
        // Sorted keys so equal models always encode to identical bytes, keeping the reload
        // fingerprint below stable across launches (dictionary key order is otherwise random).
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshots) else {
            Current.Log.error("Failed to encode watch widget complication snapshots")
            return
        }
        // Reloads are budgeted on watchOS, so identical content shouldn't burn one — but "the store
        // already holds this content" is not proof the face is showing it: the widget's self fetch
        // writes fresh values into the store without reloading the other widget instances, and a
        // suspension between a write and its reload call leaves the store fresh while the face is
        // stale. Skipping on store equality alone therefore made that staleness permanent — every
        // later refresh fetched the same value, matched the store, and never re-requested the reload.
        // The skip is instead keyed on the content this app last actually submitted to WidgetKit:
        // only content that is both unchanged AND already submitted is safe to skip. The stored blob
        // is decoded and compared as a model (not byte-wise) so writes from the widget process
        // (whose encoder doesn't sort keys) can't fake a change.
        let contentUnchanged = defaults.data(forKey: defaultsKey)
            .flatMap { try? JSONDecoder().decode([WatchWidgetComplicationSnapshot].self, from: $0) }
            .map { $0 == snapshots } ?? false
        let fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if contentUnchanged, defaults.string(forKey: reloadFingerprintKey) == fingerprint {
            return
        }
        if !contentUnchanged {
            defaults.set(data, forKey: defaultsKey)
        }
        // Reload every kind rather than a single `kind` string: the widget registers its kind from the
        // extension's `Bundle.main.bundleIdentifier`, which can differ from this app-process-derived
        // value (e.g. debug `.dev` suffixing), and a mismatched `ofKind:` is a silent no-op that leaves
        // the freshly-written snapshot unread. There is only one widget, so reloading all is equivalent.
        WidgetCenter.shared.reloadAllTimelines()
        invalidateRecommendationsIfNeeded(for: snapshots, defaults: defaults)
        // Recorded only after the reload was requested, so a suspension in between retries the
        // reload on the next refresh instead of losing it.
        defaults.set(fingerprint, forKey: reloadFingerprintKey)
    }

    /// Re-queries the widget's `recommendations()` only when the *set* of complications changed.
    /// Invalidating is a separate extension launch from the reload, and the recommendation list
    /// depends on which complications exist — not on their values — so doing it on every value change
    /// doubled the extension launches for no benefit.
    private static func invalidateRecommendationsIfNeeded(
        for snapshots: [WatchWidgetComplicationSnapshot],
        defaults: UserDefaults
    ) {
        // Name included, not just the id: renaming a complication changes what the picker lists.
        let identity = snapshots.map { "\($0.id)=\($0.menuName ?? "")" }.sorted().joined(separator: "|")
        guard defaults.string(forKey: recommendationsIdentityKey) != identity else { return }
        WidgetCenter.shared.invalidateConfigurationRecommendations()
        defaults.set(identity, forKey: recommendationsIdentityKey)
    }
}
