import Foundation
import PromiseKit
import Shared

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
    /// Set when an execution fails, so the failure isn't silent. Presented as an alert by the row.
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

    private func executeMagicItemUsingiPhone(magicItem: MagicItem, completion: @escaping (Bool) -> Void) {
        Current.Log.verbose("Signaling magic item pressed via phone")
        trace?.log(.info, "Sending to iPhone over Watch Connectivity…")
        let itemMessage = HAWatchConnectivity.InteractiveImmediateMessage(
            identifier: InteractiveImmediateMessages.magicItemPressed.rawValue,
            content: [
                "itemId": magicItem.id,
                "serverId": magicItem.serverId,
                "itemType": magicItem.type.rawValue,
                "triggeredAt": Current.date().timeIntervalSince1970,
            ],
            reply: { [weak self] message in
                Current.Log.verbose("Received reply dictionary \(message)")
                if message.content["fired"] as? Bool == true {
                    self?.trace?.log(.success, "iPhone confirmed the action ran")
                    completion(true)
                } else {
                    // The iPhone replies with a stable code plus a technical reason. The reason feeds
                    // the client-event log; the alert only shows it for `serviceCallFailed` (the
                    // server's own error message) and falls back to the localized generic text for
                    // the protocol-level codes, which are English-only diagnostics.
                    let code = (message.content["errorCode"] as? String)
                        .flatMap(MagicItemExecutionFailureCode.init(rawValue:))
                    let reason = message.content["error"] as? String
                    self?.reportFailure(
                        route: "iPhone",
                        reason: reason ?? code?.rawValue,
                        alertMessage: code == .serviceCallFailed ? reason : nil
                    )
                    completion(false)
                }
            }
        )

        Current.Log
            .verbose(
                "Sending \(InteractiveImmediateMessages.magicItemPressed.rawValue) message \(itemMessage)"
            )
        Communicator.shared.send(itemMessage, priority: .userAction, errorHandler: { [weak self] error in
            Current.Log.error("Received error when sending immediate message \(error)")
            // WatchConnectivity errors are system errors with localized descriptions.
            self?.reportFailure(
                route: "iPhone",
                reason: error.localizedDescription,
                alertMessage: error.localizedDescription
            )
            completion(false)
        })
    }

    private func executeMagicItemUsingAPI(magicItem: MagicItem, completion: @escaping (Bool) -> Void) {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == magicItem.serverId }) else {
            reportFailure(route: "Watch", reason: "Server \(magicItem.serverId) not synced to the watch")
            completion(false)
            return
        }
        Current.Log.info("Executing watch magic item directly via API")
        trace?.log(.info, "Executing via REST from the watch on \"\(server.info.name)\"…")

        magicItem.execute(on: server, source: .Watch) { [weak self] success, error in
            if success {
                self?.trace?.log(.success, "Server accepted the request")
            } else {
                // These errors implement LocalizedError (connection / TLS / HTTP body / "no active
                // URL"), so their descriptions are fit for the alert.
                self?.reportFailure(
                    route: "Watch",
                    reason: error?.localizedDescription,
                    alertMessage: error?.localizedDescription
                )
            }
            completion(success)
        }
    }

    /// Record a failure in the watch's client events (full technical `reason`, for Settings →
    /// Troubleshooting) and surface an alert on the row. The alert shows `alertMessage` when the
    /// failure carries user-fit text (a localized error or the server's own message); otherwise it
    /// falls back to the localized generic run-error message.
    private func reportFailure(route: String, reason: String?, alertMessage: String? = nil) {
        let detail = reason ?? "unknown"
        Current.clientEventStore.addEvent(.init(
            text: "Magic item \(item.id) failed to run via \(route): \(detail)",
            type: .serviceCall,
            payload: ["item": item.id, "server": item.serverId, "route": route, "reason": detail]
        ))
        trace?.log(.error, "\(route) route failed: \(detail)")
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
        // The execution runs on a dedicated thread, not Swift concurrency or a GCD global queue:
        // on watch hardware both shared pools have been observed starved (traces showed the global
        // queue never running the block within 15s), so anything queued on them never starts. A raw
        // `Thread` doesn't compete for pool workers and always starts. Every step of this path is
        // synchronous or callback-based.
        startWorkerPoolCanaries()
        let thread = Thread { [weak self] in
            self?.trace?.log(.info, "Execution started")
            self?.routeExecution(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
        }
        thread.name = "magic-item-execution"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    /// Verbose-trace diagnostics for the failure mode that used to swallow executions: schedules a
    /// no-op on each shared worker pool (Swift concurrency, GCD global) and records how long it
    /// took to run. The execution itself no longer depends on either pool, so a starved pool shows
    /// up here as a late (or missing) canary entry instead of a hang — and names which pool it is.
    private func startWorkerPoolCanaries() {
        guard let trace else { return }
        let scheduled = Current.date()
        Task {
            let elapsed = String(format: "%.2fs", Current.date().timeIntervalSince(scheduled))
            trace.log(.info, "Swift-concurrency pool canary ran after \(elapsed)", isProgress: false)
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let elapsed = String(format: "%.2fs", Current.date().timeIntervalSince(scheduled))
            trace.log(.info, "GCD global-queue canary ran after \(elapsed)", isProgress: false)
        }
    }

    /// Resolve where to run the action. Routing is automatic — the Watch pings Home Assistant
    /// directly and runs the action itself when reachable, otherwise it relays through the paired
    /// iPhone (which errors if the iPhone isn't reachable either). A forced iPhone/Watch route only
    /// applies when the developer "Allow choosing route" option re-enables the preference.
    private func routeExecution(
        magicItem: MagicItem,
        timeTriggered: Date,
        completion: @escaping (MagicItemResponse) -> Void
    ) {
        let target = WatchUserDefaults.shared.effectivePerformActionTarget
        logExecutionContext(magicItem: magicItem, target: target)
        switch target {
        case .iPhone:
            executeViaiPhone(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
        case .appleWatch:
            executeViaWatch(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
        case .auto:
            guard let server = Current.servers.all
                .first(where: { $0.identifier.rawValue == magicItem.serverId }) else {
                Current.Log.info("Auto: server not synced to the watch, relaying via iPhone")
                trace?.log(.error, "Server \(magicItem.serverId) not synced to the watch — relaying via iPhone")
                executeViaiPhone(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
                return
            }
            trace?.log(.info, "Pinging Home Assistant directly from the watch…")
            let pingStarted = Current.date()
            HomeAssistantAPI.apiAvailabilityCheck(for: server, onStep: { [weak self] step in
                self?.trace?.log(.info, step)
            }) { [weak self] available in
                guard let self else { return }
                if available {
                    Current.Log.info("Auto: Watch can reach Home Assistant directly, executing on watch")
                    trace?.log(.success, "Reached Home Assistant in \(elapsedText(since: pingStarted))")
                    executeViaWatch(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
                } else {
                    Current.Log.info("Auto: Watch cannot reach Home Assistant directly, relaying via iPhone")
                    trace?.log(
                        .error,
                        "No direct answer after \(elapsedText(since: pingStarted)) — relaying via iPhone"
                    )
                    executeViaiPhone(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
                }
            }
        }
    }

    /// Snapshot of everything relevant to routing, recorded at the start of a verbose trace.
    /// Each potentially blocking call (server list resolution) is announced before it runs, so a
    /// hang pinpoints itself: the last entry in the trace names the step that never returned.
    private func logExecutionContext(magicItem: MagicItem, target: WatchActionTarget) {
        guard let trace else { return }
        trace.log(.info, "Running \(magicItem.id) (\(magicItem.type.rawValue)) on server id \(magicItem.serverId)")
        if WatchUserDefaults.shared.allowChoosingMagicItemRoute {
            trace.log(.info, "Route preference (developer): \(target.rawValue)")
        } else {
            trace.log(.info, "Route: auto")
        }
        trace.log(.info, "iPhone reachability: \(Communicator.shared.currentReachability)")
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

    private func executeViaWatch(
        magicItem: MagicItem,
        timeTriggered: Date,
        completion: @escaping (MagicItemResponse) -> Void
    ) {
        executeMagicItemUsingAPI(magicItem: magicItem) { [weak self] success in
            self?.finishExecution(success: success, timeTriggered: timeTriggered, completion: completion)
        }
    }

    private func executeViaiPhone(
        magicItem: MagicItem,
        timeTriggered: Date,
        completion: @escaping (MagicItemResponse) -> Void
    ) {
        executeMagicItemUsingiPhone(magicItem: magicItem) { [weak self] success in
            self?.finishExecution(success: success, timeTriggered: timeTriggered, completion: completion)
        }
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
}
