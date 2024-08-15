import Foundation
import Communicator
import Shared

enum WatchHomeType {
    case undefined
    // Displays legacy home with actions and scenes
    case legacy
    // Displays home based on watch config
    case config(watchConfig: WatchConfig, magicItemsInfo: [MagicItem.Info])
}

final class WatchHomeCoordinatorViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var homeType: WatchHomeType = .undefined

    @MainActor
    func initialRoutine() {
        Reachability.observations.store[.init(queue: .main)] = { [weak self] reachability in
            guard let self else { return }
            if reachability == .immediatelyReachable {
                Communicator.shared.send(.init(identifier: InteractiveImmediateMessages.watchConfig.rawValue, reply: { message in
                    switch message.identifier {
                    case InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue:
                        self.homeType = .legacy
                    case InteractiveImmediateResponses.watchConfigResponse.rawValue:
                        self.setupConfig(message)
                    default:
                        Current.Log.error("Received unmapped response id for watch config request, id: \(message.identifier)")
                        self.homeType = .legacy
                    }
                }))
            } else {
                self.homeType = .legacy
            }
        }
    }

    @MainActor
    private func setupConfig(_ message: ImmediateMessage) {
        guard let configData = message.content["config"] as? Data else {
            Current.Log.error("Failed to get config data from watch config response")
            return
        }
        let watchConfig = WatchConfig.decodeForWatch(configData)
        print("SHOW ASSIST: \(watchConfig.showAssist)")
        guard let magicItemsInfo = message.content["magicItemsInfo"] as? [Data] else {
            Current.Log.error("Failed to get magicItemsInfo data array from watch config response")
            return
        }
        let itemsInfo = magicItemsInfo.map({ MagicItem.Info.decodeForWatch($0) })
        print("FIRST ITEM: \(String(describing: itemsInfo.first?.name))")

        self.homeType = .config(watchConfig: watchConfig, magicItemsInfo: itemsInfo)
    }
}
