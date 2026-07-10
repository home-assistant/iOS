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

    override init() {
        (self.watchConnectivityBackgroundPromise, self.watchConnectivityBackgroundSeal) = Guarantee<Void>.pending()
        super.init()
    }

    // MARK: - WKApplicationDelegate -

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.

        Current.Log.verbose("didFinishLaunching")

        UNUserNotificationCenter.current().delegate = self

        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert, .providesAppNotificationSettings]

        WKApplication.shared().registerForRemoteNotifications()

        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            Current.Log.verbose("Requested notifications access \(granted), \(String(describing: error))")
        }

        setupWatchCommunicator()
        #if DEBUG
        // Seed one example of every complication variant so they're all visible while debugging.
        WatchComplicationConfig.seedDebugFixturesIfNeeded()
        #endif
        WatchWidgetComplicationSnapshotStore.update()

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
                }.ensureThen {
                    Current.backgroundRefreshScheduler.schedule()
                }.ensure {
                    backgroundTask.setTaskCompletedWithSnapshot(false)
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
            Current.Log.verbose("Received guaranteed message! \(message)")

            if message.identifier == GuaranteedMessages.sync.rawValue {
                HomeAssistantAPI.syncWatchContext()
            }

            self?.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.blob.observations.store[.init(queue: .main)] = { blob in
            Current.Log.verbose("Received blob: \(blob.identifier)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Communicator.shared.context.observations.store[.init(queue: .main)] = { [weak self] context in
            Current.Log.verbose("Received context: \(context)")

            self?.updateContext(context.content)
        }

        Communicator.shared.complicationInfo.observations.store[.init(queue: .main)] = { complicationInfo in
            Current.Log.verbose("Received complication info: \(complicationInfo)")

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
                    self?.endWatchConnectivityBackgroundTaskIfNecessary()
                }

                watchConnectivityBackgroundPromise.done {
                    timer.invalidate()
                }

                watchConnectivityWatchdogTimer = timer
            }
        }
    }

    private func endWatchConnectivityBackgroundTaskIfNecessary() {
        DispatchQueue.main.async { [self] in
            guard !Communicator.shared.hasPendingDataToBeReceived else { return }

            // complete the current one
            watchConnectivityBackgroundSeal(())
            // and set up a new one for the next chain of updates
            (watchConnectivityBackgroundPromise, watchConnectivityBackgroundSeal) = Guarantee<Void>.pending()
        }
    }

    private func updateContext(_ content: HAWatchConnectivity.Content) {
        // Complications arrive from the phone as Codable JSON `Data` over the background context, and
        // also via the watch database mirror on reload. Both write into GRDB — the single source the
        // snapshot writer reads from.
        if let data = content["complications"] as? Data,
           let complications = try? JSONDecoder().decode([WatchComplication].self, from: data) {
            Current.Log.verbose("Updating \(complications.count) legacy complications from context")
            WatchWidgetComplicationSnapshotStore.replaceLegacyComplications(complications)
        }
        if let data = content["complicationConfigs"] as? Data,
           let configs = try? JSONDecoder().decode([WatchComplicationConfig].self, from: data) {
            Current.Log.verbose("Updating \(configs.count) complication configs from context")
            WatchWidgetComplicationSnapshotStore.replaceConfigs(configs)
        }

        WatchWidgetComplicationSnapshotStore.update()
        updateComplications()
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

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Current.Log.verbose("Successfully registered for push notifications! APNS token: \(apnsToken)")
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        Current.Log.error("Error when trying to register for push: \(error)")
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
struct ComplicationRefreshOutcome: Identifiable {
    enum Status {
        case live
        case cached
        case failed
    }

    let id: String
    let name: String
    let status: Status
    let reason: String?
}

enum WatchWidgetComplicationSnapshotStore {
    static var kind: String {
        AppConstants.BundleID + ".watchkitapp.WatchWidgets"
    }

    static let defaultsKey = "watchWidgetComplicationSnapshots"

    /// Replace the watch's legacy complications in GRDB (from the background context or the mirror).
    static func replaceLegacyComplications(_ complications: [WatchComplication]) {
        do {
            try WatchComplication.replaceAll(complications)
        } catch {
            Current.Log.error("Failed to store legacy complications: \(error)")
        }
    }

    /// Replace the watch's modern complication configs in GRDB.
    static func replaceConfigs(_ configs: [WatchComplicationConfig]) {
        do {
            try WatchComplicationConfig.replaceAll(configs)
        } catch {
            Current.Log.error("Failed to store complication configs: \(error)")
        }
    }

    /// Fire-and-forget refresh for synchronous callers (launch, context receipt, home sync).
    static func update() {
        Task { await refresh() }
    }

    /// Rebuilds every complication snapshot. Legacy complications render synchronously from their
    /// server-rendered data; modern configs fetch their live value directly from Home Assistant over
    /// REST — no paired iPhone required, so this also refreshes when the watch is on its own (e.g. on
    /// LTE), provided the server has a reachable URL. `async` so a background task can await it before
    /// completing (otherwise the app may be suspended before the REST fetch returns).
    @discardableResult
    static func refresh() async -> [ComplicationRefreshOutcome] {
        MaterialDesignIcons.register()
        let defaults = UserDefaults(suiteName: AppConstants.AppGroupID)

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
        var configSnapshots: [WatchWidgetComplicationSnapshot] = []
        var outcomes: [ComplicationRefreshOutcome] = []
        for config in configs {
            let name = config.name ?? config.entityDisplayName ?? config.entityId ?? "Complication"
            let result = await WatchWidgetComplicationSnapshot.make(config: config)
            if result.isLive {
                configSnapshots.append(result.snapshot)
                outcomes.append(.init(id: config.id, name: name, status: .live, reason: nil))
            } else if let cached = previous[config.id] {
                // Live fetch failed but we have a previous value — keep it rather than overwrite.
                configSnapshots.append(cached)
                outcomes.append(.init(id: config.id, name: name, status: .cached, reason: result.failureReason))
                Current.clientEventStore.addEvent(ClientEvent(
                    text: "Watch complication “\(name)” is showing a cached "
                        + "value; live refresh failed (\(result.failureReason ?? "unknown"))",
                    type: .backgroundOperation,
                    payload: ["complication": config.id, "reason": result.failureReason ?? "unknown"]
                ))
            } else {
                // Nothing cached (e.g. just added) — show the name-only snapshot and record the error.
                configSnapshots.append(result.snapshot)
                outcomes.append(.init(id: config.id, name: name, status: .failed, reason: result.failureReason))
                Current.clientEventStore.addEvent(ClientEvent(
                    text: "Watch complication “\(name)” "
                        + "could not load live data (\(result.failureReason ?? "unknown"))",
                    type: .networkRequest,
                    payload: ["complication": config.id, "reason": result.failureReason ?? "unknown"]
                ))
            }
        }
        write(snapshots: [.placeholder, .assist] + legacy + configSnapshots, defaults: defaults)
        let liveCount = outcomes.filter { $0.status == .live }.count
        let cachedCount = outcomes.filter { $0.status == .cached }.count
        let failedCount = outcomes.filter { $0.status == .failed }.count
        Current.clientEventStore.addEvent(ClientEvent(
            text: "Refreshed \(configs.count) watch complication(s): \(liveCount) live, "
                + "\(cachedCount) cached, \(failedCount) unavailable",
            type: .backgroundOperation,
            payload: ["live": liveCount, "cached": cachedCount, "failed": failedCount]
        ))
        return outcomes
    }

    private static func readSnapshots(_ defaults: UserDefaults?) -> [String: WatchWidgetComplicationSnapshot] {
        guard let defaults, let data = defaults.data(forKey: defaultsKey),
              let snapshots = try? JSONDecoder().decode([WatchWidgetComplicationSnapshot].self, from: data) else {
            return [:]
        }
        return Dictionary(snapshots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func write(snapshots: [WatchWidgetComplicationSnapshot], defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(snapshots), let defaults else {
            Current.Log.error("Failed to encode watch widget complication snapshots")
            return
        }
        defaults.set(data, forKey: defaultsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        WidgetCenter.shared.invalidateConfigurationRecommendations()
    }
}

/// Fetches live data for watch-rendered complications directly from Home Assistant over REST
/// (no WebSocket on watchOS), reusing the server's active URL and bearer token.
private enum ComplicationStateFetcher {
    struct EntityState {
        let state: String
        let attributes: [String: Any]
    }

    private static func bearerToken(for server: Server) async -> String? {
        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
        return try? await withCheckedThrowingContinuation { continuation in
            tokenManager.bearerToken.done { token, _ in
                continuation.resume(returning: token)
            }.catch { error in
                continuation.resume(throwing: error)
            }
        }
    }

    /// Performs `request` on the server's mTLS/self-signed-aware session (so local servers work),
    /// invalidating the session afterwards as `MagicItem.sendRESTServiceCall` does.
    private static func data(for request: URLRequest, server: Server) async -> Data? {
        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                Current.Log.error("[Complication] no HTTP response for \(request.url?.absoluteString ?? "?")")
                return nil
            }
            guard (200 ..< 300).contains(http.statusCode) else {
                Current.Log.error("[Complication] HTTP \(http.statusCode) for \(request.url?.absoluteString ?? "?")")
                return nil
            }
            return data
        } catch {
            Current.Log.error("[Complication] request failed \(request.url?.absoluteString ?? "?"): \(error)")
            return nil
        }
    }

    static func fetchState(entityId: String, server: Server) async -> EntityState? {
        guard let baseURL = await server.activeURL() else {
            Current.Log.error("[Complication] no active URL for server \(server.identifier.rawValue)")
            return nil
        }
        guard let token = await bearerToken(for: server) else {
            Current.Log.error("[Complication] no bearer token for server \(server.identifier.rawValue)")
            return nil
        }
        Current.Log.info("[Complication] fetching state for \(entityId) at \(baseURL.absoluteString)")
        var request = URLRequest(url: baseURL.appendingPathComponent("api/states/\(entityId)"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        guard let data = await data(for: request, server: server),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = json["state"] as? String else {
            return nil
        }
        return EntityState(state: state, attributes: json["attributes"] as? [String: Any] ?? [:])
    }

    static func renderTemplate(_ template: String, server: Server) async -> String? {
        guard !template.isEmpty, let baseURL = await server.activeURL(),
              let token = await bearerToken(for: server) else {
            return nil
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/template"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["template": template])
        guard let data = await data(for: request, server: server) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private struct WatchWidgetComplicationSnapshot: Codable {
    // Watch screens are @2x, so this rasterizes to 112px — safely under WidgetKit's ~122px
    // complication-image archiving limit. Anything larger makes the complication render empty.
    static let iconRenderSize = CGSize(width: 56, height: 56)

    /// Per-widget-family rendering values (varies with the config's per-size customization). Keyed by
    /// `WatchComplicationConfig.Family.rawValue`.
    struct PerFamily: Codable {
        let fraction: Double?
        let tint: String?
        let showValue: Bool
        /// Raw `WatchComplicationConfig.GaugeStyle` (circular only); nil defaults to open.
        var gaugeStyle: String?
        /// Pre-formatted gauge min/max labels for the open circular gauge.
        var minLabel: String?
        var maxLabel: String?
        /// Hex color for the value text; nil uses the default.
        var textColor: String?
    }

    let id: String
    let family: String
    let title: String
    let subtitle: String
    let inlineText: String
    let fraction: Double?
    let tint: String?
    let iconData: Data?
    let perFamily: [String: PerFamily]?
    /// Name shown in the complication picker (the value goes in `title` for on-face rendering).
    let menuName: String?

    init(
        id: String,
        family: String,
        title: String,
        subtitle: String,
        inlineText: String,
        fraction: Double?,
        tint: String?,
        iconData: Data?,
        perFamily: [String: PerFamily]? = nil,
        menuName: String? = nil
    ) {
        self.id = id
        self.family = family
        self.title = title
        self.subtitle = subtitle
        self.inlineText = inlineText
        self.fraction = fraction
        self.tint = tint
        self.iconData = iconData
        self.perFamily = perFamily
        self.menuName = menuName
    }

    /// Formats a numeric state with the entity's display precision and unit, mirroring the app.
    private static func formatValue(_ state: String, unit: String?, precision: Int?) -> String {
        var text = state
        if let precision, let number = Double(state) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = precision
            formatter.maximumFractionDigits = precision
            text = formatter.string(from: NSNumber(value: number)) ?? state
        }
        if let unit, !unit.isEmpty {
            text += " \(unit)"
        }
        return text
    }

    /// Builds a snapshot for a modern config, fetching the live entity state / rendering the custom
    /// template on the watch. The value is shared across sizes; per-family gauge/tint/showValue are
    /// resolved from the config's per-size customization. Falls back to the name when unavailable.
    static func make(
        config: WatchComplicationConfig
    ) async -> (snapshot: WatchWidgetComplicationSnapshot, isLive: Bool, failureReason: String?) {
        typealias Family = WatchComplicationConfig.Family
        let server = Current.servers.all.first(where: { $0.identifier.rawValue == config.serverId })
        if server == nil {
            Current.Log.error("[Complication] no matching server for config \(config.id) (serverId \(config.serverId))")
        }

        var valueText = ""
        var rawState = ""
        var attributes: [String: Any] = [:]
        var customGaugeFraction: Double?
        // Whether we obtained fresh live data this pass. When false the caller keeps the last-known
        // snapshot instead of overwriting it with a value-less one.
        var isLive = false
        var failureReason: String?

        switch config.kind {
        case .entity:
            guard let server else {
                failureReason = "no server configured"
                break
            }
            guard let entityId = config.entityId else {
                failureReason = "no entity configured"
                break
            }
            if let result = await ComplicationStateFetcher.fetchState(entityId: entityId, server: server) {
                rawState = result.state
                attributes = result.attributes
                // Unit comes from the live state; precision comes from the entity registry in GRDB (synced
                // to the watch) — neither is duplicated into the config. The unit is suppressed when the
                // user turned it off.
                let unit = config.showsUnit() ? result.attributes["unit_of_measurement"] as? String : nil
                let precision = EntityRegistryListForDisplay.Entity.displayPrecision(
                    serverId: config.serverId,
                    entityId: entityId
                )
                valueText = formatValue(result.state, unit: unit, precision: precision)
                isLive = true
            } else {
                failureReason = "live state unavailable"
            }
        case .customTemplate:
            guard let server else {
                failureReason = "no server configured"
                break
            }
            if let template = config.customTextTemplate,
               let rendered = await ComplicationStateFetcher.renderTemplate(template, server: server) {
                valueText = rendered
                rawState = rendered
                isLive = true
            }
            if let template = config.customGaugeTemplate,
               let rendered = await ComplicationStateFetcher.renderTemplate(template, server: server),
               let raw = WatchComplication.percentileNumber(from: rendered) {
                customGaugeFraction = min(max(Double(raw), 0), 1)
                isLive = true
            }
            if !isLive {
                failureReason = "template render failed"
            }
        }

        func fraction(for family: Family) -> Double? {
            switch config.kind {
            case .entity:
                guard let range = config.gaugeRange(for: family) else { return nil }
                let source: Any = config.gaugeAttribute(for: family).flatMap { attributes[$0] } ?? rawState
                guard let raw = WatchComplication.percentileNumber(from: source), range.max > range.min else {
                    return nil
                }
                return min(max((Double(raw) - range.min) / (range.max - range.min), 0), 1)
            case .customTemplate:
                if config.families?[family.rawValue]?.showGauge == false { return nil }
                return customGaugeFraction
            }
        }

        func label(_ value: Double) -> String {
            value == value.rounded() ? String(Int(value)) : String(value)
        }

        var perFamily: [String: PerFamily] = [:]
        for family in Family.allCases {
            let range = config.gaugeRange(for: family)
            perFamily[family.rawValue] = PerFamily(
                fraction: fraction(for: family),
                tint: config.tint(for: family),
                showValue: config.showsValue(for: family),
                gaugeStyle: config.gaugeStyle(for: family).rawValue,
                minLabel: range.map { label($0.min) },
                maxLabel: range.map { label($0.max) },
                textColor: config.textColor(for: family)
            )
        }

        let name = config.name ?? config.entityDisplayName ?? config.entityId ?? "Complication"
        let color = config.iconColor.map { UIColor($0) } ?? AppConstants.tintColor
        let iconData = config.iconName
            .map { MaterialDesignIcons(named: $0).image(ofSize: iconRenderSize, color: color) }?
            .pngData()

        let snapshot = WatchWidgetComplicationSnapshot(
            id: config.id,
            family: "",
            title: valueText.isEmpty ? name : valueText,
            subtitle: name,
            inlineText: [name, valueText].filter { !$0.isEmpty }.joined(separator: " "),
            fraction: fraction(for: config.widgetFamily),
            tint: config.tint(for: config.widgetFamily),
            iconData: iconData,
            perFamily: perFamily,
            menuName: name
        )
        return (snapshot, isLive, failureReason)
    }

    init(complication: WatchComplication) {
        let textAreas = Self.textAreas(from: complication.Data)
        let renderedTextAreas = Self.renderedTextAreas(from: complication.Data)
        let preferredText = Self.firstText(
            from: renderedTextAreas,
            textAreas,
            keys: ["Center", "InsideRing", "Line1", "Header", "Body1", "Row1Column1"]
        )
        let secondaryText = Self.firstText(
            from: renderedTextAreas,
            textAreas,
            keys: ["Line2", "Body2", "Row1Column2", "Row2Column1", "Row2Column2"]
        )
        let resolvedTitle = preferredText ?? complication.displayName
        let resolvedFraction = Self.fraction(from: complication.Data)

        self.init(
            id: complication.identifier,
            family: complication.Family.rawValue,
            title: resolvedTitle,
            subtitle: secondaryText ?? complication.Template.style,
            inlineText: [resolvedTitle, secondaryText].compactMap { $0 }.joined(separator: " "),
            fraction: resolvedFraction,
            tint: Self.tint(from: complication.Data),
            iconData: Self.iconData(from: complication.Data),
            perFamily: nil,
            menuName: complication.displayName
        )
    }

    static var placeholder: WatchWidgetComplicationSnapshot {
        .init(
            id: "placeholder",
            family: "",
            title: "Home Assistant",
            subtitle: "Complication",
            inlineText: "Home Assistant",
            fraction: nil,
            tint: nil,
            // No icon payload: the widget extension renders its bundled (correctly sized) Logo asset.
            iconData: nil
        )
    }

    static var assist: WatchWidgetComplicationSnapshot {
        .init(
            id: AssistDefaultComplication.defaultComplicationId,
            family: "",
            title: AssistDefaultComplication.title,
            subtitle: "Home Assistant",
            inlineText: AssistDefaultComplication.title,
            fraction: nil,
            tint: nil,
            // No icon payload: the widget extension renders its bundled Assist symbol via the fallback path.
            iconData: nil
        )
    }

    private static func textAreas(from data: [String: Any]) -> [String: String] {
        guard let textAreas = data["textAreas"] as? [String: [String: Any]] else { return [:] }

        return textAreas.compactMapValues { $0["text"] as? String }
    }

    private static func renderedTextAreas(from data: [String: Any]) -> [String: String] {
        guard let rendered = data["rendered"] as? [String: Any] else { return [:] }

        return rendered.reduce(into: [String: String]()) { result, item in
            guard item.key.hasPrefix("textArea,") else { return }

            let key = String(item.key.dropFirst("textArea,".count))
            result[key] = String(describing: item.value)
        }
    }

    private static func firstText(
        from renderedTextAreas: [String: String],
        _ textAreas: [String: String],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let rendered = renderedTextAreas[key], rendered.isEmpty == false {
                return rendered
            } else if let configured = textAreas[key], configured.isEmpty == false {
                return configured
            }
        }

        return nil
    }

    private static func fraction(from data: [String: Any]) -> Double? {
        if let rendered = data["rendered"] as? [String: Any] {
            if let ringValue = rendered["ring"].flatMap(percentileNumber(from:)) {
                return ringValue
            } else if let gaugeValue = rendered["gauge"].flatMap(percentileNumber(from:)) {
                return gaugeValue
            }
        }

        if let ring = data["ring"] as? [String: String],
           let value = ring["ring_value"].flatMap(percentileNumber(from:)) {
            return value
        }

        if let gauge = data["gauge"] as? [String: String], let value = gauge["gauge"].flatMap(percentileNumber(from:)) {
            return value
        }

        return nil
    }

    private static func percentileNumber(from value: Any) -> Double? {
        WatchComplication.percentileNumber(from: value).map(Double.init)
    }

    private static func tint(from data: [String: Any]) -> String? {
        if let ring = data["ring"] as? [String: String], let color = ring["ring_color"] {
            return color
        }

        if let gauge = data["gauge"] as? [String: String], let color = gauge["gauge_color"] {
            return color
        }

        return nil
    }

    private static func iconData(from data: [String: Any]) -> Data? {
        guard let icon = data["icon"] as? [String: String], let name = icon["icon"] else {
            return nil
        }

        let color = icon["icon_color"].map { UIColor($0) } ?? AppConstants.tintColor
        // The stored name may be a server-side value (e.g. "mdi:music"); normalize before lookup so
        // image-based legacy complications (e.g. "Ring Image") actually resolve an icon.
        return MaterialDesignIcons(serversideValueNamed: name)
            .image(ofSize: iconRenderSize, color: color)
            .pngData()
    }
}
