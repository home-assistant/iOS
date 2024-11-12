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
    @Published var showAssist = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published private(set) var homeType: WatchHomeType = .undefined

    @Published var watchConfig: WatchConfig = .init()
    @Published var magicItemsInfo: [MagicItem.Info] = []

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
            clearCacheAndLoad()
        case InteractiveImmediateResponses.watchConfigResponse.rawValue:
            setupConfig(message)
        default:
            Current.Log
                .error("Received unmapped response id for watch config request, id: \(message.identifier)")
            loadCache()
        }
        updateLoading(isLoading: false)
    }

    @MainActor
    func loadCache() {
        let configPromise: Promise<WatchConfig> = Current.diskCache.value(for: watchConfigCacheKey)
        configPromise.pipe { [weak self] result in
            self?.handleCacheResponse(result)
        }
    }

    @MainActor
    private func clearCacheAndLoad() {
        let emptyConfig: WatchConfig? = nil
        let emptyMagicItems: [MagicItem]? = nil
        _ = Current.diskCache.set(emptyConfig, for: watchConfigCacheKey)
        _ = Current.diskCache.set(emptyMagicItems, for: magicItemsInfoCacheKey)
        loadCache()
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
            displayError(message: L10n.Watch.Config.Cache.Error.message)
            updateConfig(config: .init(), magicItemsInfo: [])
        }

        updateLoading(isLoading: false)
    }

    @MainActor
    private func handleMagicItemsCacheResponse(result: Result<[MagicItem.Info]>, watchConfig: WatchConfig) {
        switch result {
        case let .fulfilled(magicItemsInfo):
            updateConfig(config: watchConfig, magicItemsInfo: magicItemsInfo)
            resetError()
        case let .rejected(error):
            Current.Log.error("Failed to retrieve magic items cache, error: \(error.localizedDescription)")
            displayError(message: L10n.Watch.Config.Error.message(error.localizedDescription))
        }
    }

    @MainActor
    private func setupConfig(_ message: ImmediateMessage) {
        guard let configData = message.content["config"] as? Data,
              let watchConfig = WatchConfig.decodeForWatch(configData) else {
            Current.Log.error("Failed to get config data from watch config response")
            return
        }

        guard let magicItemsInfo = message.content["magicItemsInfo"] as? [Data] else {
            Current.Log.error("Failed to get magicItemsInfo data array from watch config response")
            return
        }
        let itemsInfo = magicItemsInfo.map({ MagicItem.Info.decodeForWatch($0) })
        Current.diskCache.set(watchConfig, for: watchConfigCacheKey).cauterize()
        Current.diskCache.set(itemsInfo, for: magicItemsInfoCacheKey).cauterize()

        loadCache()
    }

    private func updateConfig(config: WatchConfig, magicItemsInfo: [MagicItem.Info]) {
        DispatchQueue.main.async { [weak self] in
            self?.watchConfig = config
            self?.magicItemsInfo = magicItemsInfo

            if config.assist.showAssist,
               !config.assist.serverId.isEmpty,
               !config.assist.pipelineId.isEmpty {
                self?.showAssist = true
            } else {
                self?.showAssist = false
            }
        }
    }

    private func updateLoading(isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = isLoading
        }
    }

    private func displayError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
        }
    }

    private func resetError() {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = ""
            self?.showError = false
        }
    }
}
