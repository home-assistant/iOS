import Communicator
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

    @Published private(set) var state: RowState = .idle
    @Published var showConfirmationDialog = false

    @Published private(set) var item: MagicItem
    @Published private(set) var itemInfo: MagicItem.Info

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
        state = .loading
        executeMagicItem { [weak self] success in
            DispatchQueue.main.async { [weak self] in
                self?.state = success ? .success : .failure
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
        NEHotspotNetwork.fetchCurrent { hotspotNetwork in
            WatchUserDefaults.shared.set(hotspotNetwork?.ssid, key: .watchSSID)
            completion?()
        }
    }

    private func executeMagicItemUsingiPhone(magicItem: MagicItem, completion: @escaping (Bool) -> Void) {
        Current.Log.verbose("Signaling magic item pressed via phone")
        let itemMessage = InteractiveImmediateMessage(
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
        Communicator.shared.send(itemMessage, errorHandler: { error in
            Current.Log.error("Received error when sending immediate message \(error)")
            completion(false)
        })
    }

    private func executeMagicItemUsingAPI(magicItem: MagicItem, completion: @escaping (Bool) -> Void) {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == magicItem.serverId }) else {
            completion(false)
            return
        }
        Current.Log.error("Executing watch magic item directly via API")
        Current.api(for: server).executeMagicItem(item: magicItem) { success in
            completion(success)
        }
    }

    private func executeMagicItem(completion: @escaping (Bool) -> Void) {
        let magicItem = item
        Current.Log.verbose("Selected magic item id: \(magicItem.id)")
        fetchNetworkInfo { [weak self] in
            guard let self else { return }
            if Communicator.shared.currentReachability == .immediatelyReachable {
                executeMagicItemUsingiPhone(magicItem: magicItem) { success in
                    if success {
                        completion(success)
                    } else {
                        self.executeMagicItemUsingAPI(magicItem: magicItem) { success in
                            completion(success)
                        }
                    }
                }
            } else {
                executeMagicItemUsingAPI(magicItem: magicItem) { success in
                    completion(success)
                }
            }
        }
    }
}
