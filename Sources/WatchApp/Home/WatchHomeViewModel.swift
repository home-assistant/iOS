import Communicator
import Foundation
import NetworkExtension
import PromiseKit
import Shared

enum WatchHomeType {
    case undefined
    case empty
    case config(watchConfig: WatchConfig, magicItemsInfo: [MagicItem.Info])
    case error(message: String)
}

final class WatchHomeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showAssist = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published private(set) var homeType: WatchHomeType = .undefined

    @Published var watchConfig: WatchConfig = .init()
    @Published var magicItemsInfo: [MagicItem.Info] = []

    // If the watchConfig items are the same but it's customization properties
    // are different, the list won't refresh. This is a workaround to force a refresh
    @Published var refreshListID: UUID = .init()

    func fetchNetworkInfo(completion: (() -> Void)? = nil) {
        NEHotspotNetwork.fetchCurrent { hotspotNetwork in
            WatchUserDefaults.shared.set(hotspotNetwork?.ssid, key: .watchSSID)
            completion?()
        }
    }

    @MainActor
    func initialRoutine() {
        isLoading = true
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

    func info(for magicItem: MagicItem) -> MagicItem.Info {
        magicItemsInfo.first(where: {
            $0.id == magicItem.serverUniqueId
        }) ?? .init(
            id: magicItem.id,
            name: magicItem.id,
            iconName: ""
        )
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

        do {
            try Current.database().write { db in
                try watchConfig.insert(db, onConflict: .replace)
            }
            saveItemsInfoInCache(itemsInfo.compactMap({ $0 }))
        } catch {
            Current.Log
                .error(
                    "Failed to save watch config and/or magic item info in database on Apple watch, error: \(error.localizedDescription)"
                )
        }

        loadCache()
    }

    @MainActor
    func loadCache() {
        do {
            if let watchConfig = try Current.database().read({ db in
                try WatchConfig.fetchOne(db)
            }) {
                loadInformationCache(watchConfig: watchConfig)
            } else {
                updateConfig(config: .init(), magicItemsInfo: [])
            }
        } catch {
            Current.Log.error("Failed to fetch watch config from database, error: \(error.localizedDescription)")
            displayError(message: L10n.Watch.Config.Cache.Error.message)
            updateConfig(config: .init(), magicItemsInfo: [])
        }
    }

    @MainActor
    private func loadInformationCache(watchConfig: WatchConfig) {
        let magicItemsInfo = getItemsInfoFromCache()
        if !magicItemsInfo.isEmpty {
            updateConfig(config: watchConfig, magicItemsInfo: magicItemsInfo)
            resetError()
        } else {
            Current.Log.error("Failed to retrieve magic items cache")
            displayError(message: L10n.Watch.Config.Error.message("No information cached"))
        }
        updateLoading(isLoading: false)
    }

    @MainActor
    private func clearCacheAndLoad() {
        do {
            _ = try Current.database().write { db in
                try WatchConfig.deleteAll(db)
            }
        } catch {
            Current.Log
                .error(
                    "Failed to delete watch config and/or magic item info in database on Apple watch, error: \(error.localizedDescription)"
                )
        }

        deleteItemsInfoInCache()
        loadCache()
    }

    private func saveItemsInfoInCache(_ itemsInfo: [MagicItem.Info]) {
        do {
            let fileURL = AppConstants.watchMagicItemsInfo
            let jsonData = try JSONEncoder().encode(itemsInfo)
            try jsonData.write(to: fileURL)
            Current.Log
                .verbose("JSON saved successfully for watch magic items info, file URL: \(fileURL.absoluteString)")
        } catch {
            Current.Log.error("Error saving JSON for magic items info: \(error)")
        }
    }

    private func deleteItemsInfoInCache() {
        do {
            let fileURL = AppConstants.watchMagicItemsInfo
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            Current.Log.error("Error deleting JSON for magic items info: \(error)")
        }
    }

    private func getItemsInfoFromCache() -> [MagicItem.Info] {
        let fileURL = AppConstants.watchMagicItemsInfo
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Current.Log.error("Watch magic items info cache file doesn't exist at path: \(fileURL.absoluteString)")
            return []
        }

        let data = FileManager.default.contents(atPath: fileURL.path) ?? Data()

        do {
            let infos = try JSONDecoder().decode([MagicItem.Info].self, from: data)
            return infos
        } catch {
            Current.Log.error("Failed to decode watch magic item info data from cache, error: \(error)")
            return []
        }
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
            self?.refreshListID = UUID()
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
