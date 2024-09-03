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
        guard state != .loading else { return }
        if item.customization?.requiresConfirmation ?? false {
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

    private func executeMagicItem(completion: @escaping (Bool) -> Void) {
        let magicItem = item
        Current.Log.verbose("Selected magic item id: \(magicItem.id)")
        fetchNetworkInfo {
            firstly { () -> Promise<Void> in
                Promise { seal in
                    guard Communicator.shared.currentReachability == .immediatelyReachable else {
                        seal.reject(WatchSendError.notImmediate)
                        return
                    }

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
                                seal.fulfill(())
                            } else {
                                seal.reject(WatchSendError.phoneFailed)
                            }
                        }
                    )

                    Current.Log
                        .verbose(
                            "Sending \(InteractiveImmediateMessages.magicItemPressed.rawValue) message \(itemMessage)"
                        )
                    Communicator.shared.send(itemMessage, errorHandler: { error in
                        Current.Log.error("Received error when sending immediate message \(error)")
                        seal.reject(error)
                    })
                }
            }.recover { error -> Promise<Void> in
                guard let error = error as? WatchSendError, error == WatchSendError.notImmediate,
                      let server = Current.servers.all.first(where: { $0.identifier.rawValue == magicItem.serverId }) else {
                    throw error
                }
                Current.Log.error("recovering error \(error) by trying locally")

                switch magicItem.type {
                case .script:
                    let domain = Domain.script.rawValue
                    let service = magicItem.id.replacingOccurrences(of: "\(domain).", with: "")
                    return Current.api(for: server).CallService(
                        domain: domain,
                        service: service,
                        serviceData: [:],
                        shouldLog: true
                    )
                case .action:
                    return Current.api(for: server).HandleAction(actionID: magicItem.id, source: .Watch)
                case .scene:
                    let domain = Domain.scene.rawValue
                    return Current.api(for: server).CallService(
                        domain: domain,
                        service: "turn_on",
                        serviceData: ["entity_id": magicItem.id],
                        shouldLog: true
                    )
                }
            }.done {
                completion(true)
            }.catch { err in
                Current.Log.error("Error during magic item event fire: \(err)")
                completion(false)
            }
        }
    }
}
