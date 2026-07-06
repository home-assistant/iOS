import Foundation
import NetworkExtension
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

    private func fetchNetworkInfo(completion: (() -> Void)? = nil) {
        Current.networkInformation { hotspotNetwork in
            WatchUserDefaults.shared.set(hotspotNetwork?.ssid, key: .watchSSID)
            completion?()
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
        let timeTriggered = Date()
        let magicItem = item
        Current.Log.verbose("Selected magic item id: \(magicItem.id)")
        fetchNetworkInfo { [weak self] in
            guard let self else { return }
            if shouldUsePhone {
                executeMagicItemUsingiPhone(magicItem: magicItem) { success in
                    // Avoid haptics in background
                    guard self.isLessThan30Seconds(from: timeTriggered) else {
                        completion(.tookLonger)
                        return
                    }
                    if success {
                        self.cancelTimeout()
                        completion(success ? .success : .failed)
                    } else {
                        completion(.failed)
                    }
                }
            } else {
                executeMagicItemUsingAPI(magicItem: magicItem) { success in
                    self.cancelTimeout()
                    completion(success ? .success : .failed)
                }
            }
            startTimeoutTimerWhichResetsState(completion: completion)
        }
    }

    /// Resolve where to run the action from the user's "Perform action using" preference: always the
    /// iPhone, always the Watch (direct), or automatically (iPhone when reachable, else direct).
    private var shouldUsePhone: Bool {
        switch WatchUserDefaults.shared.performActionTarget {
        case .iPhone:
            return true
        case .appleWatch:
            return false
        case .auto:
            return Communicator.shared.currentReachability == .immediatelyReachable
        }
    }

    // Given date returns if is less than 30 seconds from now
    private func isLessThan30Seconds(from date: Date) -> Bool {
        Date().timeIntervalSince(date) < 30
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
