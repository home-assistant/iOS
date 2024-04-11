import Foundation
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
    var state: WatchHomeViewState { get set }
    func onAppear()
    func onDisappear()
    func runActionId(_ actionId: String)
}

enum WatchHomeViewState {
    case loading
    case success
    case failure
    case idle
}

final class WatchHomeViewModel: WatchHomeViewModelProtocol {
    @Published var actions: [WatchActionItem] = []
    @Published var state: WatchHomeViewState = .idle {
        didSet {
            resetStateToIdleIfNeeded()
        }
    }

    private var actionsToken: NotificationToken?
    private var realmActions: [Action] = []

    func onAppear() {
        setupActionsObservation()
    }

    func onDisappear() {
        actionsToken?.invalidate()
    }

    func runActionId(_ actionId: String) {
        guard let selectedAction = realmActions.first(where: { $0.ID == actionId }) else { return }

        Current.Log.verbose("Selected action id: \(actionId)")

        guard let server = Current.servers.server(for: selectedAction) else {
            Current.Log.verbose("Failed to get server for action id: \(actionId)")
            return
        }

        setState(.loading)

        Current.api(for: server).HandleAction(actionID: actionId, source: .Watch).pipe { [weak self] result in
            switch result {
            case .fulfilled:
                self?.setState(.success)
            case let .rejected(error):
                Current.Log.info(error)
                self?.setState(.failure)
            }
        }
    }

    private func setState(_ state: WatchHomeViewState) {
        DispatchQueue.main.async { [weak self] in
            self?.state = state
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

    private func resetStateToIdleIfNeeded() {
        switch state {
        case .success, .failure:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.state = .idle
            }
        default:
            break
        }
    }
}

private extension Action {
    func toWatchActionItem() -> WatchActionItem {
        .init(
            id: ID,
            name: Name,
            iconName: IconName,
            backgroundColor: BackgroundColor,
            iconColor: IconColor,
            textColor: TextColor
        )
    }
}
