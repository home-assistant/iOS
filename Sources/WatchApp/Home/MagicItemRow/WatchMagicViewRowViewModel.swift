import Darwin
import Foundation
import HAKit
import Shared
import WatchKit

final class WatchMagicViewRowViewModel: ObservableObject {
    enum RowState {
        case idle
        case loading
        case success
        case failure
    }

    enum MagicItemResponse {
        case success
        case failed
        case tookLonger

        var rowState: RowState {
            switch self {
            case .success:
                return .success
            case .failed:
                return .failure
            case .tookLonger:
                return .idle
            }
        }
    }

    @Published private(set) var state: RowState = .idle
    @Published var showConfirmationDialog = false
    /// Alert shown when the tapped entity's domain has no action the watch can perform.
    @Published var showUnsupportedAlert = false
    /// Drives the details screen for a display-only (sensor) item, which runs nothing when tapped.
    @Published var showDetails = false
    /// Latest entity snapshot from the poller; drives the state subtitle, the live icon, and the
    /// state-aware execution (lock).
    @Published private(set) var liveEntity: HAEntity?
    /// True when the state couldn't be refreshed within the poller's stale interval — the row shows
    /// a small warning badge so the displayed state isn't mistaken for current.
    @Published private(set) var isStateStale = false
    /// Set when an execution fails, so the failure isn't silent. Presented full-screen by the row.
    @Published var errorMessage: String?
    /// Live log of the current execution, set only when the developer "Verbose item execution"
    /// option is on. Presented full-screen by the row while it runs.
    @Published private(set) var trace: MagicItemExecutionTrace?
    @Published var showTrace = false

    @Published private(set) var item: MagicItem
    @Published private(set) var itemInfo: MagicItem.Info

    private var timeoutWorkItem: DispatchWorkItem?
    private var watchdogWorkItem: DispatchWorkItem?
    /// Shared REST polling used by every screen that shows live state (see `WatchEntityStatePoller`).
    private let poller: WatchEntityStatePoller

    init(item: MagicItem, itemInfo: MagicItem.Info) {
        self.item = item
        self.itemInfo = itemInfo
        self.poller = WatchEntityStatePoller(entityId: item.id, serverId: item.serverId)
    }

    func executeItem() {
        // Sensors are on the watch to be read, not run: open their details screen instead.
        guard !isDisplayOnly else {
            showDetails = true
            return
        }
        guard isActionable else {
            showUnsupportedAlert = true
            return
        }
        if itemInfo.customization?.requiresConfirmation ?? true {
            showConfirmationDialog = true
        } else {
            executeItemAction()
        }
    }

    /// The screen the entire row (icon included) opens. Locks never toggle from the home screen —
    /// they're security-sensitive, so every tap lands on the lock screen where the action is an
    /// explicit button press. Climate has no single tap action at all, so its rows navigate the
    /// same way. Unlike `controlsDestination` this doesn't wait for the polled state: the pushed
    /// screens handle an unknown state themselves.
    var wholeRowNavigationDestination: WatchHomeNavigation? {
        guard item.type == .entity, let domain = item.domain else { return nil }
        switch domain {
        case .lock:
            return .lockControls(item)
        case .climate:
            return .climateControls(item)
        case .vacuum:
            return .vacuumControls(item)
        default:
            return nil
        }
    }

    /// The controls screen this row's body pushes, once the polled state proves the entity can do
    /// more than toggle (dim a light, position a cover, set a fan's speed…). Nil until the first
    /// snapshot arrives — or for entities without adjustable capabilities — so a tap just toggles.
    var controlsDestination: WatchHomeNavigation? {
        guard item.type == .entity, let liveEntity, let domain = item.domain else { return nil }
        switch domain {
        case .light:
            return LightCapabilities(entity: liveEntity).hasAdjustableControls ? .lightControls(item) : nil
        case .cover:
            return CoverCapabilities(entity: liveEntity).hasAdjustableControls ? .coverControls(item) : nil
        case .fan:
            return FanCapabilities(entity: liveEntity).hasAdjustableControls ? .fanControls(item) : nil
        default:
            return nil
        }
    }

    // MARK: - Entity state

    var domainName: String {
        if let domain = item.domain {
            return domain.name
        }
        // Unknown domains still need a readable alert — fall back to the entity id prefix.
        return item.id.components(separatedBy: ".").first ?? item.id
    }

    var stateText: String? {
        guard let liveEntity, let domain = item.domain else { return nil }
        return domain.contextualStateDescription(for: liveEntity, serverId: item.serverId)
    }

    /// Mirrors CarPlay: only the domains whose icon changes with state render the live icon, and
    /// only until the user explicitly picks one of their own.
    var icon: MaterialDesignIcons {
        if let liveEntity, usesLiveIcon {
            return liveEntity.getMDI()
        }
        return item.icon(info: itemInfo)
    }

    /// The color home-assistant/frontend gives the entity, the same as the widgets and CarPlay —
    /// independent of which icon is drawn, so a custom icon still shows whether the thing is on.
    /// Items with no live entity behind them (scripts, scenes, Assist) keep their configured color.
    var iconColor: UIColor {
        if let liveEntity, item.type == .entity {
            let customColor = itemInfo.customization?.customIconColor.map { UIColor(hex: $0) }
            return liveEntity.stateIconColor(customColor: customColor) ?? .white
        }
        if let hex = itemInfo.customization?.iconColor {
            return UIColor(hex: hex)
        }
        return .white
    }

    private var usesLiveIcon: Bool {
        guard item.type == .entity, let domain = item.domain else { return false }
        return domain.hasStateDependentIcon && itemInfo.customization?.iconIsCustomized != true
    }

    /// Sensor rows are read-only: tapping shows the details screen instead of running an action, and
    /// the row surfaces the value rather than an execution result.
    var isDisplayOnly: Bool {
        item.isWatchDisplayOnly
    }

    private var isActionable: Bool {
        switch item.type {
        case .entity:
            return item.domain?.isActionable ?? false
        default:
            return true
        }
    }

    /// State is only fetched for entity items whose domain reports a meaningful state — same
    /// rule as CarPlay.
    private var displaysState: Bool {
        guard item.type == .entity, let domain = item.domain else { return false }
        return !domain.hasIrrelevantState
    }

    /// Polls the entity state while the row is on screen; `stopStateUpdates` (on disappear) ends it.
    func startStateUpdates() {
        stopStateUpdates()
        guard displaysState else { return }
        poller.start { [weak self] snapshot in
            self?.liveEntity = snapshot.entity
            self?.isStateStale = snapshot.isStale
        }
    }

    func stopStateUpdates() {
        poller.stop()
    }

    /// Reflect an executed action (e.g. a toggled light) quickly instead of waiting up to a full
    /// poll interval. Skipped when the row is no longer polling (it disappeared meanwhile).
    private func scheduleStateRefreshAfterExecution() {
        guard displaysState else { return }
        poller.refresh(after: 1)
    }

    func confirmationAction() {
        executeItemAction()
    }

    private func executeItemAction() {
        errorMessage = nil
        state = .loading
        if WatchUserDefaults.shared.verboseItemExecution {
            trace = MagicItemExecutionTrace()
            showTrace = true
        } else {
            trace = nil
        }
        executeMagicItem { [weak self] response in
            DispatchQueue.main.async { [weak self] in
                self?.state = response.rowState
                self?.scheduleStateRefreshAfterExecution()
            }
            self?.resetState()
        }
    }

    private func resetState() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.state = .idle
        }
    }

    private func executeMagicItemUsingAPI(magicItem: MagicItem, completion: @escaping (Bool) -> Void) {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == magicItem.serverId }) else {
            reportFailure(reason: "Server \(magicItem.serverId) not synced to the watch")
            completion(false)
            return
        }
        Current.Log.info("Executing watch magic item directly via API")
        trace?.log(.info, "Executing via REST from the watch on \"\(server.info.name)\"…")

        // Each REST stage (service call, URL, token, request, TLS) announces itself before it
        // runs, so a hang's last trace line names the exact step that never returned. Nil when
        // verbose execution is off, so the run skips the narration (and its probes) entirely.
        let onStep: ((String) -> Void)? = trace == nil ? nil : { [weak self] step in
            self?.trace?.log(.info, step)
        }
        magicItem.execute(
            on: server,
            source: .Watch,
            currentItemState: liveEntity?.state ?? "",
            onStep: onStep
        ) { [weak self] success, error in
            if success {
                self?.trace?.log(.success, "Server accepted the request")
            } else {
                // These errors implement LocalizedError (connection / TLS / HTTP body / "no active
                // URL"), so their descriptions are fit for the error screen. The no-URL case gets
                // an extra line pointing at the per-server URL options in the watch settings.
                var message = error?.localizedDescription
                if error?.isNoActiveURLError == true {
                    message = [message, L10n.Watch.Home.Run.Error.noActiveUrlHint]
                        .compactMap { $0 }
                        .joined(separator: "\n\n")
                }
                self?.reportFailure(
                    reason: error?.localizedDescription,
                    alertMessage: message
                )
            }
            completion(success)
        }
    }

    /// Record a failure in the watch's client events (full technical `reason`, for Settings →
    /// Troubleshooting) and surface a full-screen error from the row. The screen shows
    /// `alertMessage` when the failure carries user-fit text (a localized error or the server's
    /// own message); otherwise it falls back to the localized generic run-error message.
    private func reportFailure(reason: String?, alertMessage: String? = nil) {
        let detail = reason ?? "unknown"
        Current.clientEventStore.addEvent(.init(
            text: "Magic item \(item.id) failed to run: \(detail)",
            type: .serviceCall,
            payload: ["item": item.id, "server": item.serverId, "reason": detail]
        ))
        let currentTrace = trace
        currentTrace?.log(.error, "Execution failed: \(detail)")
        // The census names the queues holding GCD workers (a worker thread is named after the queue
        // it is currently running), so a starvation-driven failure pinpoints its own culprit.
        currentTrace?.log(.info, "Threads at failure: \(Self.threadCensus())", isProgress: false)
        // `WKApplication.shared()` is main-thread-only, and failures can be reported from URLSession
        // callback queues; `trace.log` itself is thread-safe.
        DispatchQueue.main.async {
            currentTrace?.log(.info, "Process at failure: \(Self.processStateSummary())", isProgress: false)
        }
        // The verbose trace screen already shows the failure; presenting the alert underneath the
        // full-screen cover would just fight it.
        guard currentTrace == nil else { return }
        let message = alertMessage ?? L10n.Watch.Home.Run.Error.message
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
        }
    }

    private func executeMagicItem(completion: @escaping (MagicItemResponse) -> Void) {
        let timeTriggered = Current.date()
        let magicItem = item
        Current.Log.verbose("Selected magic item id: \(magicItem.id)")
        startTimeoutTimerWhichResetsState(completion: completion)
        logExecutionContext(magicItem: magicItem)
        // Always executed from the watch's own networking — there is no iPhone relay. Runs directly
        // on the caller (main) thread: every step is synchronous or callback-based, and starting the
        // URLSession task doesn't block.
        executeMagicItemUsingAPI(magicItem: magicItem) { [weak self] success in
            self?.finishExecution(success: success, timeTriggered: timeTriggered, completion: completion)
        }
    }

    /// Snapshot of everything relevant to the execution, recorded at the start of a verbose trace.
    /// Each potentially blocking call (server list resolution) is announced before it runs, so a
    /// hang pinpoints itself: the last entry in the trace names the step that never returned.
    private func logExecutionContext(magicItem: MagicItem) {
        guard let trace else { return }
        trace.log(.info, "Running \(magicItem.id) (\(magicItem.type.rawValue)) on server id \(magicItem.serverId)")
        // Resolving the server name reads the ServerManager cache, which can block on its lock (held
        // during Keychain writes by server sync) or on cold Keychain/GRDB reads.
        trace.log(.info, "Resolving server name…")
        let serverName = Current.servers.all
            .first(where: { $0.identifier.rawValue == magicItem.serverId })?.info.name
            ?? "unknown (id \(magicItem.serverId))"
        trace.log(.info, "Server: \"\(serverName)\"")
        // The last-known state is read synchronously — the watch has no network info of its own,
        // so this is always current (and the SSID always empty) on watchOS.
        if let ssid = Current.connectivity.lastKnownNetworkState().ssid {
            trace.log(.info, "Watch Wi-Fi: \(ssid)")
        } else {
            trace.log(.info, "No Wi-Fi on watch (traffic may proxy via iPhone or LTE)")
        }
    }

    private func elapsedText(since date: Date) -> String {
        String(format: "%.2fs", Current.date().timeIntervalSince(date))
    }

    private func finishExecution(
        success: Bool,
        timeTriggered: Date,
        completion: @escaping (MagicItemResponse) -> Void
    ) {
        // Avoid haptics in background
        guard isLessThan30Seconds(from: timeTriggered) else {
            trace?.log(.error, "Result arrived after 30s — ignored (\(success ? "success" : "failure"))")
            trace?.finish()
            completion(.tookLonger)
            return
        }
        cancelTimeout()
        trace?.log(
            success ? .success : .error,
            "Finished \(success ? "successfully" : "with failure") in \(elapsedText(since: timeTriggered))"
        )
        trace?.finish()
        completion(success ? .success : .failed)
    }

    // Given date returns if is less than 30 seconds from now
    private func isLessThan30Seconds(from date: Date) -> Bool {
        Current.date().timeIntervalSince(date) < 30
    }

    private func startTimeoutTimerWhichResetsState(completion: @escaping (MagicItemResponse) -> Void) {
        timeoutWorkItem?.cancel()
        watchdogWorkItem?.cancel()

        timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let lastStep = trace?.lastProgressMessage ?? "execution never started"
            trace?.log(
                .info,
                "Still waiting after 4s — row resets while execution continues (last step: \(lastStep))",
                isProgress: false
            )
            completion(.tookLonger)
        }

        // Second, later checkpoint: if the execution is still silent well past the UI timeout it is
        // most likely stuck (not just slow), so leave a trace of the step it never came back from.
        watchdogWorkItem = DispatchWorkItem { [weak self] in
            guard let self, let trace else { return }
            let lastStep = trace.lastProgressMessage ?? "execution never started"
            trace.log(
                .error,
                "Still no result after 15s — execution appears stuck (last step: \(lastStep))",
                isProgress: false
            )
            trace.log(.error, "Threads at hang: \(Self.threadCensus())", isProgress: false)
            trace.log(.error, "Process at hang: \(Self.processStateSummary())", isProgress: false)
        }

        if let workItem = timeoutWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
        }
        if let workItem = watchdogWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: workItem)
        }
    }

    private func cancelTimeout() {
        timeoutWorkItem?.cancel()
        watchdogWorkItem?.cancel()
    }

    /// A one-line census of the process's threads: total count plus a histogram of thread names.
    /// GCD names a worker thread after the queue it is currently running, so when the worker pool
    /// is starved (main alive, global queues silent — the observed watch hang signature) the
    /// blocked workers carry the labels of the queues that wedged them. Logged into the verbose
    /// trace when a run fails or the watchdog declares it stuck.
    private static func threadCensus() -> String {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)
        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threadList else {
            return "thread info unavailable"
        }
        defer {
            for index in 0 ..< Int(threadCount) {
                mach_port_deallocate(mach_task_self_, threadList[index])
            }
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threadList)),
                vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            )
        }

        var histogram: [String: Int] = [:]
        var runStates: [String: Int] = [:]
        for index in 0 ..< Int(threadCount) {
            var info = thread_extended_info_data_t()
            var infoCount = mach_msg_type_number_t(
                MemoryLayout<thread_extended_info_data_t>.size / MemoryLayout<natural_t>.size
            )
            let result = withUnsafeMutablePointer(to: &info) { infoPointer in
                infoPointer.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threadList[index], thread_flavor_t(THREAD_EXTENDED_INFO), $0, &infoCount)
                }
            }
            guard result == KERN_SUCCESS else { continue }
            var name = withUnsafeBytes(of: info.pth_name) { buffer in
                String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
            }
            if name.isEmpty { name = "unnamed" }
            // Priority distinguishes a clamped process (everything at background priority) from a
            // normal one; run state distinguishes parked workers from busy ones.
            histogram["\(name) pri:\(info.pth_curpri)", default: 0] += 1
            let stateLabel: String
            switch info.pth_run_state {
            case TH_STATE_RUNNING: stateLabel = "running"
            case TH_STATE_WAITING: stateLabel = "waiting"
            case TH_STATE_UNINTERRUPTIBLE: stateLabel = "blocked"
            case TH_STATE_STOPPED: stateLabel = "stopped"
            default: stateLabel = "other"
            }
            runStates[stateLabel, default: 0] += 1
        }

        let states = runStates
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { "\($0.value) \($0.key)" }
            .joined(separator: ", ")
        let summary = histogram
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { "\($0.value)× \($0.key)" }
            .joined(separator: ", ")
        return "\(threadCount) total (\(states)) — \(summary)"
    }

    /// The process/lifecycle facts that decide whether background QoS should be serviced at all:
    /// a run whose sub-user-interactive probes never fire while the app claims to be `.active` is
    /// clamped from outside (RunningBoard/scheduler), not blocked by its own code. Main-thread only
    /// (`WKApplication` requirement) — both watchdog and failure paths already run there.
    private static func processStateSummary() -> String {
        let appState: String
        switch WKApplication.shared().applicationState {
        case .active: appState = "active"
        case .inactive: appState = "inactive"
        case .background: appState = "background"
        @unknown default: appState = "unknown"
        }
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unknown"
        }
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled ? "on" : "off"
        return "app: \(appState), thermal: \(thermal), low power: \(lowPower)"
    }
}
