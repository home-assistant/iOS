import Communicator
import Foundation
import PromiseKit
import Shared

enum WatchHomeType {
    case undefined
    case empty
    case config(watchConfig: WatchConfig, magicItemsInfo: [MagicItem.Info])
}

final class WatchHomeCoordinatorViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var homeType: WatchHomeType = .undefined

    private let watchConfigCacheKey = "watch-config"
    private let magicItemsInfoCacheKey = "magic-items-info"

    func initialRoutine() {
        homeType = .undefined
        loadCache()
        Reachability.observations.store[.init(queue: .main)] = { [weak self] reachability in
            guard let self else { return }
            if reachability == .notReachable {
                loadCache()
            } else {
                requestConfig()
            }
        }
    }

    func requestConfig() {
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfig.rawValue,
            reply: { message in
                switch message.identifier {
                case InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue:
                    self.loadCache()
                case InteractiveImmediateResponses.watchConfigResponse.rawValue:
                    self.setupConfig(message)
                default:
                    Current.Log
                        .error("Received unmapped response id for watch config request, id: \(message.identifier)")
                    self.loadCache()
                }
            }
        ))
    }

    private func loadCache() {
        let configPromise: Promise<WatchConfig> = Current.diskCache.value(for: watchConfigCacheKey)
        let magicItemsPromise: Promise<[MagicItem.Info]> = Current.diskCache.value(for: magicItemsInfoCacheKey)
        configPromise.pipe { [weak self] result in
            switch result {
            case let .fulfilled(config):
                magicItemsPromise.pipe { result in
                    switch result {
                    case let .fulfilled(magicItems):
                        DispatchQueue.main.async { [weak self] in
                            self?.homeType = .config(watchConfig: config, magicItemsInfo: magicItems)
                        }
                    case let .rejected(error):
                        Current.Log.error("Failed to retrieve magic items cache, error: \(error.localizedDescription)")
                        self?.presentEmptyState()
                    }
                }
            case let .rejected(error):
                Current.Log.error("Failed to retrieve watch config cache, error: \(error.localizedDescription)")
                self?.presentEmptyState()
            }
        }
    }

    private func presentEmptyState() {
        DispatchQueue.main.async { [weak self] in
            self?.homeType = .empty
        }
    }

    private func setupConfig(_ message: ImmediateMessage) {
        guard let configData = message.content["config"] as? Data else {
            Current.Log.error("Failed to get config data from watch config response")
            return
        }
        let watchConfig = WatchConfig.decodeForWatch(configData)
        guard let magicItemsInfo = message.content["magicItemsInfo"] as? [Data] else {
            Current.Log.error("Failed to get magicItemsInfo data array from watch config response")
            return
        }
        let itemsInfo = magicItemsInfo.map({ MagicItem.Info.decodeForWatch($0) })
        Current.diskCache.set(watchConfig, for: watchConfigCacheKey).cauterize()
        Current.diskCache.set(itemsInfo, for: magicItemsInfoCacheKey).cauterize()

        DispatchQueue.main.async { [weak self] in
            self?.homeType = .config(watchConfig: watchConfig, magicItemsInfo: itemsInfo)
        }
    }
}
