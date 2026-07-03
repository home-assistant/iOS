import Foundation
import NetworkExtension
import PromiseKit
import Shared
import SwiftUI

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
    @Published var currentSSID: String = ""
    @Published private(set) var homeType: WatchHomeType = .undefined

    @Published var watchConfig: WatchConfig = .init()
    @Published var magicItemsInfo: [MagicItem.Info] = []
    /// Changes every time a new config is fetched, used as a `.id()` modifier on lists to force re-render.
    @Published var configVersion = UUID()
    /// Set when the watch and iPhone both changed the config since the last sync; the UI prompts the
    /// user to choose which to keep.
    @Published var pendingConflict: ConfigConflict?

    @MainActor
    func fetchNetworkInfo() async {
        let networkInformation = await Current.networkInformation
        WatchUserDefaults.shared.set(networkInformation?.ssid, key: .watchSSID)
        currentSSID = networkInformation?.ssid ?? ""
    }

    @MainActor
    func initialRoutine() {
        // First display whatever is in cache
        loadCache()
        // Now fetch new data in the background (shows loading indicator only for this fetch)
        isLoading = true
        requestConfig()
    }

    @MainActor
    func requestConfig() {
        homeType = .undefined
        guard Communicator.shared.currentReachability != .notReachable else {
            Current.Log.error("iPhone reachability is not immediate reachable")
            loadCache()
            return
        }
        isLoading = true
        // Pull servers + any mTLS client certificates as part of the refresh (delivered inline).
        WatchServerSync.request()
        // Refresh the offline reference mirror (entities/areas/pipelines) so configuring works offline.
        fetchDatabaseMirror()
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfig.rawValue,
            reply: { [weak self] message in
                Task { @MainActor in self?.reconcile(with: message) }
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

    // MARK: - Offline-aware config reconciliation

    /// Handle the phone's reply to a config pull, deciding whether to adopt it, push local offline
    /// edits, or (when both sides changed) surface a conflict for the user to resolve.
    @MainActor
    private func reconcile(with message: HAWatchConnectivity.ImmediateMessage) {
        switch message.identifier {
        case InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue:
            reconcile(phoneConfig: nil, phoneItemsInfo: [])
        case InteractiveImmediateResponses.watchConfigResponse.rawValue:
            guard let configData = message.content["config"] as? Data,
                  let phoneConfig = WatchConfig.decodeForWatch(configData),
                  let infoData = message.content["magicItemsInfo"] as? [Data] else {
                Current.Log.error("Failed to decode watch config response")
                loadCache()
                updateLoading(isLoading: false)
                return
            }
            reconcile(
                phoneConfig: phoneConfig,
                phoneItemsInfo: infoData.compactMap { MagicItem.Info.decodeForWatch($0) }
            )
        default:
            Current.Log.error("Received unmapped response id for watch config request, id: \(message.identifier)")
            loadCache()
            updateLoading(isLoading: false)
        }
    }

    @MainActor
    private func reconcile(phoneConfig: WatchConfig?, phoneItemsInfo: [MagicItem.Info]) {
        let localConfig = (try? WatchConfig.config()) ?? nil
        let baseline = WatchUserDefaults.shared.lastSyncedModified ?? 0
        let phoneModified = phoneConfig?.lastModified ?? 0
        let localModified = localConfig?.lastModified ?? 0
        let watchChanged = localConfig != nil && localModified != baseline
        let phoneChanged = phoneModified != baseline

        if !watchChanged {
            // Neither changed, or only the phone changed → take the phone's config.
            adopt(phoneConfig: phoneConfig, itemsInfo: phoneItemsInfo)
        } else if !phoneChanged {
            // Only the watch changed (offline edits) → push them to the phone.
            pushLocalConfig(localConfig)
        } else {
            // Both changed since the last sync → let the user decide.
            pendingConflict = ConfigConflict(phoneConfig: phoneConfig, phoneItemsInfo: phoneItemsInfo)
            updateLoading(isLoading: false)
        }
    }

    /// Overwrite the local config with the phone's and record it as the synced baseline.
    @MainActor
    func adopt(phoneConfig: WatchConfig?, itemsInfo: [MagicItem.Info]) {
        do {
            try Current.database().write { db in
                try WatchConfig.deleteAll(db)
                if var config = phoneConfig {
                    config.id = WatchConfig.watchConfigId
                    try config.insert(db, onConflict: .replace)
                }
            }
            saveItemsInfoInCache(itemsInfo)
        } catch {
            Current.Log.error("Failed to adopt phone watch config: \(error.localizedDescription)")
        }
        WatchUserDefaults.shared.lastSyncedModified = phoneConfig?.lastModified
        pendingConflict = nil
        loadCache()
        updateLoading(isLoading: false)
    }

    /// Push the watch's local config to the phone (source of truth), then adopt the echoed result as
    /// the new synced baseline.
    @MainActor
    func pushLocalConfig(_ config: WatchConfig?) {
        guard let config else {
            adopt(phoneConfig: nil, itemsInfo: [])
            return
        }
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfigUpdate.rawValue,
            content: ["config": config.encodeForWatch()],
            reply: { [weak self] message in
                Task { @MainActor in self?.adoptPushReply(message) }
            }
        ), errorHandler: { [weak self] error in
            Current.Log.error("Failed to push watch config: \(error.localizedDescription)")
            Task { @MainActor in
                self?.loadCache()
                self?.updateLoading(isLoading: false)
            }
        })
    }

    @MainActor
    private func adoptPushReply(_ message: HAWatchConnectivity.ImmediateMessage) {
        if message.identifier == InteractiveImmediateResponses.watchConfigResponse.rawValue,
           let configData = message.content["config"] as? Data,
           let phoneConfig = WatchConfig.decodeForWatch(configData),
           let infoData = message.content["magicItemsInfo"] as? [Data] {
            adopt(phoneConfig: phoneConfig, itemsInfo: infoData.compactMap { MagicItem.Info.decodeForWatch($0) })
        } else {
            loadCache()
            updateLoading(isLoading: false)
        }
    }

    /// Refresh the offline reference tables (entities/areas/pipelines) from the phone.
    private func fetchDatabaseMirror() {
        guard isPhoneReachable else { return }
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchDatabaseMirror.rawValue,
            reply: { message in
                guard let data = message.content["mirror"] as? Data,
                      let mirror = WatchDatabaseMirror.decodeForWatch(data) else { return }
                do {
                    try mirror.apply()
                } catch {
                    Current.Log.error("Failed to apply watch database mirror: \(error.localizedDescription)")
                }
            }
        ), errorHandler: { error in
            Current.Log.error("Failed to fetch watch database mirror: \(error.localizedDescription)")
        })
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
        if !magicItemsInfo.isEmpty || watchConfig.items.isEmpty {
            updateConfig(config: watchConfig, magicItemsInfo: magicItemsInfo)
            resetError()
        } else {
            Current.Log.error("Failed to retrieve magic items cache")
            displayError(message: L10n.Watch.Config.Error.message("No information cached"))
        }
        updateLoading(isLoading: false)
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
            self?.configVersion = UUID()

            if config.assist.showAssist,
               config.assist.serverId != nil,
               config.assist.pipelineId != nil {
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
