import Communicator
import Foundation
import PromiseKit
import RealmSwift
import Shared

struct WatchActionItem: Equatable {
    let id: String
    let name: String
    let iconName: String
    let backgroundColor: String
    let iconColor: String
    let textColor: String
}

protocol WatchHomeViewModelProtocol: ObservableObject {
    var actions: [WatchActionItem] { get set }
    func onAppear()
    func onDisappear()
    func runActionId(_ actionId: String, completion: @escaping (Bool) -> Void)
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
}

final class WatchHomeViewModel: WatchHomeViewModelProtocol {
    @Published var actions: [WatchActionItem] = []

    private var actionsToken: NotificationToken?
    private var realmActions: [Action] = []

    func onAppear() {
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
            guard error == WatchSendError.notImmediate, let server = Current.servers.server(for: selectedAction) else {
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
            backgroundColor: BackgroundColor,
            iconColor: IconColor,
            textColor: TextColor
        )
    }
}
