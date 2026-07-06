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

    @Published private(set) var item: MagicItem
    @Published private(set) var itemInfo: MagicItem.Info

    private var timeoutWorkItem: DispatchWorkItem?

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
        let itemMessage = HAWatchConnectivity.InteractiveImmediateMessage(
            identifier: InteractiveImmediateMessages.magicItemPressed.rawValue,
            content: [
                "itemId": magicItem.id,
                "serverId": magicItem.serverId,
                "itemType": magicItem.type.rawValue,
                "triggeredAt": Current.date().timeIntervalSince1970,
            ],
            reply: { message in
                Current.Log.verbose("Received reply dictionary \(message)")
                if message.content["fired"] as? Bool == true {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        )

        Current.Log
            .verbose(
                "Sending \(InteractiveImmediateMessages.magicItemPressed.rawValue) message \(itemMessage)"
            )
        Communicator.shared.send(itemMessage, errorHandler: { [weak self] error in
            Current.Log.error("Received error when sending immediate message \(error)")
            self?.presentError(error)
            completion(false)
        })
    }

    private func executeMagicItemUsingAPI(magicItem: MagicItem, completion: @escaping (Bool) -> Void) {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == magicItem.serverId }) else {
            presentError(nil)
            completion(false)
            return
        }
        Current.Log.error("Executing watch magic item directly via API")

        magicItem.execute(on: server, source: .Watch) { [weak self] success, error in
            if !success {
                self?.presentError(error)
            }
            completion(success)
        }
    }

    /// Surface a failure to the user instead of letting it fail silently. Uses the underlying
    /// error's description when available (e.g. a connection / TLS / "no active URL" error).
    private func presentError(_ error: Error?) {
        let message = error?.localizedDescription ?? L10n.Watch.Home.Run.Error.message
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
        }
    }

    private func executeMagicItem(completion: @escaping (MagicItemResponse) -> Void) {
        let timeTriggered = Current.date()
        let magicItem = item
        Current.Log.verbose("Selected magic item id: \(magicItem.id)")
        startTimeoutTimerWhichResetsState(completion: completion)
        Task { [weak self] in
            await self?.routeExecution(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
        }
    }

    /// Resolve where to run the action from the user's "Perform action using" preference: always the
    /// iPhone, always the Watch (direct), or automatically. In `auto` the Watch is preferred: it pings
    /// Home Assistant directly and runs the action itself when reachable, otherwise it relays through
    /// the paired iPhone (which errors if the iPhone isn't reachable either).
    private func routeExecution(
        magicItem: MagicItem,
        timeTriggered: Date,
        completion: @escaping (MagicItemResponse) -> Void
    ) async {
        switch WatchUserDefaults.shared.performActionTarget {
        case .iPhone:
            executeViaiPhone(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
        case .appleWatch:
            await Current.connectivity.refreshNetworkInformation()
            executeViaWatch(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
        case .auto:
            if let server = Current.servers.all.first(where: { $0.identifier.rawValue == magicItem.serverId }),
               await HomeAssistantAPI.apiAvailabilityCheck(for: server) {
                Current.Log.info("Auto: Watch can reach Home Assistant directly, executing on watch")
                executeViaWatch(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
            } else {
                Current.Log.info("Auto: Watch cannot reach Home Assistant directly, relaying via iPhone")
                executeViaiPhone(magicItem: magicItem, timeTriggered: timeTriggered, completion: completion)
            }
        }
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
            completion(.tookLonger)
            return
        }
        cancelTimeout()
        completion(success ? .success : .failed)
    }

    // Given date returns if is less than 30 seconds from now
    private func isLessThan30Seconds(from date: Date) -> Bool {
        Current.date().timeIntervalSince(date) < 30
    }

    private func startTimeoutTimerWhichResetsState(completion: @escaping (MagicItemResponse) -> Void) {
        timeoutWorkItem?.cancel()

        timeoutWorkItem = DispatchWorkItem {
            completion(.tookLonger)
        }

        if let workItem = timeoutWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
        }
    }

    private func cancelTimeout() {
        timeoutWorkItem?.cancel()
    }
}
