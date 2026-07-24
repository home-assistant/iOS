import Darwin
import Foundation
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

    init(item: MagicItem, itemInfo: MagicItem.Info) {
        self.item = item
        self.itemInfo = itemInfo
    }

    func executeItem() {
        if itemInfo.customization?.requiresConfirmation ?? true {
            showConfirmationDialog = true
        } else {
            executeItemAction()
        }
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

        magicItem.execute(on: server, source: .Watch, onStep: { [weak self] step in
            // Each REST stage (service call, URL, token, request, TLS) announces itself before it
            // runs, so a hang's last trace line names the exact step that never returned.
            self?.trace?.log(.info, step)
        }) { [weak self] success, error in
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
        trace?.log(.error, "Execution failed: \(detail)")
        // The census names the queues holding GCD workers (a worker thread is named after the queue
        // it is currently running), so a starvation-driven failure pinpoints its own culprit.
        trace?.log(.info, "Threads at failure: \(Self.threadCensus())", isProgress: false)
        // `WKApplication.shared()` is main-thread-only, and failures can be reported from URLSession
        // callback queues; `trace.log` itself is thread-safe.
        let trace = trace
        DispatchQueue.main.async {
            trace?.log(.info, "Process at failure: \(Self.processStateSummary())", isProgress: false)
        }
        // The verbose trace screen already shows the failure; presenting the alert underneath the
        // full-screen cover would just fight it.
        guard trace == nil else { return }
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
