import Communicator
import Foundation
import PromiseKit
import Shared

enum WatchHomeType {
    case undefined
    case empty
    case config(watchConfig: WatchConfig, magicItemsInfo: [MagicItem.Info])
    case error(message: String)
}

final class WatchHomeCoordinatorViewModel: ObservableObject {
    @Published var isLoading = false
    @Published private(set) var homeType: WatchHomeType = .undefined

    @Published private(set) var config: WatchConfig?

    private let watchConfigCacheKey = "watch-config"
    private let magicItemsInfoCacheKey = "magic-items-info"

    @MainActor
    func initialRoutine() {
        isLoading = true
        loadCache()
        requestConfig()
    }

    @MainActor
    func requestConfig() {
        homeType = .undefined
        isLoading = true
        guard Communicator.shared.currentReachability != .notReachable else {
            Current.Log.error("iPhone reachability is not immediate reachable")
            loadCache()
            return
        }
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfig.rawValue,
            reply: { [weak self] message in
                self?.handleMessageResponse(message)
            }
        ))
    }

    @MainActor
    private func handleMessageResponse(_ message: ImmediateMessage) {
        switch message.identifier {
        case InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue:
            loadCache()
        case InteractiveImmediateResponses.watchConfigResponse.rawValue:
            setupConfig(message)
        default:
            Current.Log
                .error("Received unmapped response id for watch config request, id: \(message.identifier)")
            loadCache()
        }
        isLoading = false
    }

    @MainActor
    func loadCache() {
        homeType = .undefined
        let configPromise: Promise<WatchConfig> = Current.diskCache.value(for: watchConfigCacheKey)
        configPromise.pipe { [weak self] result in
            self?.handleCacheResponse(result)
        }
    }

    @MainActor
    private func handleCacheResponse(_ result: Result<WatchConfig>) {
        let magicItemsPromise: Promise<[MagicItem.Info]> = Current.diskCache.value(for: magicItemsInfoCacheKey)

        switch result {
        case let .fulfilled(config):
            magicItemsPromise.pipe { [weak self] result in
                self?.handleMagicItemsCacheResponse(result: result, watchConfig: config)
            }
        case let .rejected(error):
            Current.Log.error("Failed to retrieve watch config cache, error: \(error.localizedDescription)")
            homeType = .error(message: "Failed to load watch config, error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    @MainActor
    private func handleMagicItemsCacheResponse(result: Result<[MagicItem.Info]>, watchConfig: WatchConfig) {
        config = watchConfig
        switch result {
        case let .fulfilled(magicItems):
            homeType = .config(watchConfig: watchConfig, magicItemsInfo: magicItems)
        case let .rejected(error):
            Current.Log.error("Failed to retrieve magic items cache, error: \(error.localizedDescription)")
            homeType = .error(message: "Failed to load watch config, error: \(error.localizedDescription)")
        }
    }

    @MainActor
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

        loadCache()
    }
}
