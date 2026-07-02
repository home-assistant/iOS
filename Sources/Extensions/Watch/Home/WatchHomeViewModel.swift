import Communicator
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
    /// Surfaced when an on-watch edit can't be applied (iPhone unreachable, save/fetch failed).
    @Published var editErrorMessage: String?

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
        if !magicItemsInfo.isEmpty || watchConfig.items.isEmpty {
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

// MARK: - On-watch editing

extension WatchHomeViewModel {
    enum WatchConfigEditError: Error {
        case notReachable
        case sendFailed
        case decodeFailed
    }

    /// Every edit needs an immediate round-trip to the phone (the source of truth), so we require the
    /// phone to be immediately reachable, matching `WatchServerSync.request()`. These mutation methods
    /// mirror the iPhone `WatchConfigurationViewModel`; they run on the main thread (SwiftUI event
    /// handlers) and are deliberately not actor-isolated so they can be called from `onMove`/`onDelete`
    /// closures and from callback closures, just like the iPhone view model.
    var isPhoneReachable: Bool {
        Communicator.shared.currentReachability == .immediatelyReachable
    }

    // MARK: Servers

    /// Whether the configured items span more than one server (folders have no server).
    var hasMultipleConfiguredServers: Bool {
        Set(configuredServerIds).count > 1
    }

    private var configuredServerIds: [String] {
        watchConfig.items.flatMap { item -> [String] in
            item.type == .folder ? (item.items ?? []).map(\.serverId) : [item.serverId]
        }.filter { !$0.isEmpty }
    }

    /// The server name to show as a subtitle for an item, only when the config spans multiple servers.
    func serverName(for item: MagicItem) -> String? {
        guard hasMultipleConfiguredServers, item.type != .folder, !item.serverId.isEmpty else { return nil }
        return Current.servers.server(forServerIdentifier: item.serverId)?.info.name
    }

    // MARK: Root-level mutations (mirror iPhone WatchConfigurationViewModel)

    func addItem(_ item: MagicItem, info: MagicItem.Info?) {
        watchConfig.items.append(item)
        seedInfo(info)
    }

    func addFolder(named name: String, iconName: String?) {
        let folder = MagicItem(
            id: UUID().uuidString,
            serverId: "",
            type: .folder,
            customization: .init(
                iconColor: Color.haPrimary.hex(),
                icon: iconName,
                iconIsCustomized: iconName != nil
            ),
            action: .default,
            displayText: name,
            items: []
        )
        watchConfig.items.append(folder)
    }

    /// Replace an item (or folder) in place, wherever it lives (root or inside a folder), preserving a
    /// folder's children. Used for name/icon edits — the caller passes a fully-built item so all other
    /// customization (colors, confirmation) and the action are preserved.
    func updateItem(_ item: MagicItem, info: MagicItem.Info?) {
        if let index = watchConfig.items.firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) {
            var updated = item
            if item.type == .folder {
                updated.items = watchConfig.items[index].items
            }
            watchConfig.items[index] = updated
            seedInfo(info)
            return
        }
        for (folderIndex, folder) in watchConfig.items.enumerated() where folder.type == .folder {
            guard var items = folder.items,
                  let index = items.firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) else { continue }
            items[index] = item
            var updatedFolder = folder
            updatedFolder.items = items
            watchConfig.items[folderIndex] = updatedFolder
            seedInfo(info)
            return
        }
    }

    func deleteItem(at offsets: IndexSet) {
        watchConfig.items.remove(atOffsets: offsets)
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        watchConfig.items.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: Folder-scoped mutations

    func addItemToFolder(folderId: String, item: MagicItem, info: MagicItem.Info?) {
        guard let index = watchConfig.items.firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = watchConfig.items[index]
        var items = folder.items ?? []
        items.append(item)
        folder.items = items
        watchConfig.items[index] = folder
        seedInfo(info)
    }

    func deleteItemInFolder(folderId: String, at offsets: IndexSet) {
        guard let index = watchConfig.items.firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = watchConfig.items[index]
        var items = folder.items ?? []
        items.remove(atOffsets: offsets)
        folder.items = items
        watchConfig.items[index] = folder
    }

    func moveItemWithinFolder(folderId: String, from source: IndexSet, to destination: Int) {
        guard let index = watchConfig.items.firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = watchConfig.items[index]
        var items = folder.items ?? []
        items.move(fromOffsets: source, toOffset: destination)
        folder.items = items
        watchConfig.items[index] = folder
    }

    /// Remove an item (or folder) wherever it lives — the root or inside a folder.
    func removeItem(_ item: MagicItem) {
        if let index = watchConfig.items.firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) {
            watchConfig.items.remove(at: index)
            return
        }
        for (folderIndex, folder) in watchConfig.items.enumerated() where folder.type == .folder {
            guard var items = folder.items,
                  let index = items.firstIndex(where: { $0.id == item.id && $0.serverId == item.serverId }) else { continue }
            items.remove(at: index)
            var updatedFolder = folder
            updatedFolder.items = items
            watchConfig.items[folderIndex] = updatedFolder
            return
        }
    }

    // MARK: Persistence

    /// Persist the current working copy to the phone (single source of truth). The phone writes it to
    /// GRDB and replies with the authoritative config + resolved info, handled by the existing
    /// `watchConfig` response path. On failure we revert to the persisted config and surface an error.
    func saveConfig() {
        guard isPhoneReachable else {
            editErrorMessage = L10n.Watch.Config.Edit.Error.notReachable
            return
        }
        isLoading = true
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfigUpdate.rawValue,
            content: ["config": watchConfig.encodeForWatch()],
            reply: { [weak self] message in
                Task { @MainActor in self?.handleMessageResponse(message) }
            }
        ), errorHandler: { [weak self] error in
            Current.Log.error("Failed to send watch config update: \(error.localizedDescription)")
            Task { @MainActor in
                self?.isLoading = false
                self?.editErrorMessage = L10n.Watch.Config.Edit.Error.saveFailed
                self?.loadCache()
            }
        })
    }

    // MARK: Available items

    /// Ask the phone for the items the user can add (scripts/scenes/automations across all servers).
    func fetchAvailableItems(
        completion: @escaping (Swift.Result<WatchConfigAvailableItems, WatchConfigEditError>)
            -> Void
    ) {
        guard isPhoneReachable else {
            completion(.failure(.notReachable))
            return
        }
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfigAvailableItems.rawValue,
            reply: { message in
                DispatchQueue.main.async {
                    guard let data = message.content["availableItems"] as? Data,
                          let items = WatchConfigAvailableItems.decodeForWatch(data) else {
                        completion(.failure(.decodeFailed))
                        return
                    }
                    completion(.success(items))
                }
            }
        ), errorHandler: { error in
            Current.Log.error("Failed to fetch available watch items: \(error.localizedDescription)")
            DispatchQueue.main.async { completion(.failure(.sendFailed)) }
        })
    }

    private func seedInfo(_ info: MagicItem.Info?) {
        guard let info else { return }
        if let index = magicItemsInfo.firstIndex(where: { $0.id == info.id }) {
            magicItemsInfo[index] = info
        } else {
            magicItemsInfo.append(info)
        }
    }
}
