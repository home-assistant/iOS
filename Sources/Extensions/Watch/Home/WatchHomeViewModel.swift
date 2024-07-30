import Communicator
import Foundation
import NetworkExtension
import PromiseKit
import RealmSwift
import Shared

struct WatchActionItem: Equatable {
    let id: String
    let name: String
    let iconName: String
    let iconColor: String
    let backgroundColor: String
    let textColor: String
    let useCustomColors: Bool
}

protocol WatchHomeViewModelProtocol: ObservableObject {
    var actions: [WatchActionItem] { get }
    func onAppear()
    func onDisappear()
    func runActionId(_ actionId: String, completion: @escaping (Bool) -> Void)
    func fetchNetworkInfo(completion: (() -> Void)?)
}

enum WatchHomeViewState {
    case loading
    case success
    case failure
    case idle
}

enum WatchSendError: Error {
    case notImmediate
    case phoneFailed
    case wrongAudioURLData
}

final class WatchHomeViewModel: WatchHomeViewModelProtocol {
    @Published private(set) var actions: [WatchActionItem] = []
    private var actionsToken: NotificationToken?
    private var realmActions: [Action] = []

    func onAppear() {
        fetchNetworkInfo()
        setupActionsObservation()
    }

    func onDisappear() {
        actionsToken?.invalidate()
    }

    func runActionId(_ actionId: String, completion: @escaping (Bool) -> Void) {
        guard let selectedAction = realmActions.first(where: { $0.ID == actionId }) else {
            completion(false)
            return
        }

        Current.Log.verbose("Selected action id: \(actionId)")
        fetchNetworkInfo {
            firstly { () -> Promise<Void> in
                Promise { seal in
                    guard Communicator.shared.currentReachability == .immediatelyReachable else {
                        seal.reject(WatchSendError.notImmediate)
                        return
                    }

                    Current.Log.verbose("Signaling action pressed via phone")
                    let actionMessage = InteractiveImmediateMessage(
                        identifier: InteractiveImmediateMessages.actionRowPressed.rawValue,
                        content: ["ActionID": selectedAction.ID],
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
                            "Sending \(InteractiveImmediateMessages.actionRowPressed.rawValue) message \(actionMessage)"
                        )
                    Communicator.shared.send(actionMessage, errorHandler: { error in
                        Current.Log.error("Received error when sending immediate message \(error)")
                        seal.reject(error)
                    })
                }
            }.recover { error -> Promise<Void> in
                guard error == WatchSendError.notImmediate,
                      let server = Current.servers.server(for: selectedAction) else {
                    throw error
                }

                Current.Log.error("recovering error \(error) by trying locally")
                return Current.api(for: server).HandleAction(actionID: selectedAction.ID, source: .Watch)
            }.done {
                completion(true)
            }.catch { err in
                Current.Log.error("Error during action event fire: \(err)")
                completion(false)
            }
        }
    }

    func fetchNetworkInfo(completion: (() -> Void)? = nil) {
        NEHotspotNetwork.fetchCurrent { hotspotNetwork in
            WatchUserDefaults.shared.set(hotspotNetwork?.ssid, key: .watchSSID)
            completion?()
        }
    }

    private func setupActionsObservation() {
        let actions = Current.realm().objects(Action.self)
            .sorted(byKeyPath: "Position")
            .filter("showInWatch == true")

        actionsToken?.invalidate()
        actionsToken = actions.observe { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .initial(collectionType):
                    self?.realmActions = collectionType.map({ $0 })
                    self?.actions = collectionType.map({ $0.toWatchActionItem() })
                case let .update(collectionType, _, _, _):
                    self?.realmActions = collectionType.map({ $0 })
                    self?.actions = collectionType.map({ $0.toWatchActionItem() })
                case let .error(error):
                    Current.Log
                        .error("Error happened on observe actions for Apple Watch: \(error.localizedDescription)")
                }
            }
        }
    }
}

private extension Action {
    func toWatchActionItem() -> WatchActionItem {
        .init(
            id: ID,
            name: Text,
            iconName: IconName,
            iconColor: IconColor,
            backgroundColor: BackgroundColor,
            textColor: TextColor,
            useCustomColors: useCustomColors
        )
    }
}
