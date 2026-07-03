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
    private func reconcile(with message: ImmediateMessage) {
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
    private func adopt(phoneConfig: WatchConfig?, itemsInfo: [MagicItem.Info]) {
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
    private func adoptPushReply(_ message: ImmediateMessage) {
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

// MARK: - On-watch editing

extension WatchHomeViewModel {
    enum WatchConfigEditError: Error {
        case notReachable
        case sendFailed
        case decodeFailed
    }

    /// Edits are applied locally first (so they work offline) and pushed to the phone — the source of
    /// truth — only when it's immediately reachable, matching `WatchServerSync.request()`. The mutation
    /// methods below mirror the iPhone `WatchConfigurationViewModel`; they run on the main thread
    /// (SwiftUI event handlers) and are deliberately not actor-isolated so they can be called from
    /// `onMove`/`onDelete` closures and from callback closures, just like the iPhone view model.
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

    /// Move a root item one position up/down. Drag-to-reorder is unreliable on watchOS, so the edit
    /// UI drives reordering with explicit arrows.
    func moveItemUp(at index: Int) {
        guard index > 0, index < watchConfig.items.count else { return }
        watchConfig.items.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
    }

    func moveItemDown(at index: Int) {
        guard index >= 0, index < watchConfig.items.count - 1 else { return }
        watchConfig.items.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
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

    func moveItemUpInFolder(folderId: String, at index: Int) {
        guard let folderIndex = watchConfig.items.firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = watchConfig.items[folderIndex]
        var items = folder.items ?? []
        guard index > 0, index < items.count else { return }
        items.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
        folder.items = items
        watchConfig.items[folderIndex] = folder
    }

    func moveItemDownInFolder(folderId: String, at index: Int) {
        guard let folderIndex = watchConfig.items.firstIndex(where: { $0.type == .folder && $0.id == folderId }) else { return }
        var folder = watchConfig.items[folderIndex]
        var items = folder.items ?? []
        guard index >= 0, index < items.count - 1 else { return }
        items.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
        folder.items = items
        watchConfig.items[folderIndex] = folder
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

    /// Persist the working copy locally so offline edits survive, and — when the phone is reachable —
    /// push it to the phone (source of truth). Offline edits sync, or prompt on conflict, on the next
    /// reload.
    @MainActor
    func saveConfig() {
        watchConfig.stampModified()
        persistLocalConfig(watchConfig)
        guard isPhoneReachable else { return }
        isLoading = true
        pushLocalConfig(watchConfig)
    }

    private func persistLocalConfig(_ config: WatchConfig) {
        do {
            try Current.database().write { db in
                var config = config
                if config.id != WatchConfig.watchConfigId {
                    try WatchConfig.deleteAll(db)
                    config.id = WatchConfig.watchConfigId
                }
                try config.insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to persist watch config locally: \(error.localizedDescription)")
        }
    }

    // MARK: Conflict resolution

    struct ConfigConflict {
        let phoneConfig: WatchConfig?
        let phoneItemsInfo: [MagicItem.Info]
    }

    @MainActor
    func resolveConflictKeepingWatch() {
        let local = (try? WatchConfig.config()) ?? nil
        pendingConflict = nil
        isLoading = true
        pushLocalConfig(local)
    }

    @MainActor
    func resolveConflictUsingiPhone() {
        let conflict = pendingConflict
        pendingConflict = nil
        isLoading = true
        adopt(phoneConfig: conflict?.phoneConfig, itemsInfo: conflict?.phoneItemsInfo ?? [])
    }

    // MARK: Available items

    /// Build the list of addable items (scripts/scenes/automations across all servers) from the
    /// locally-mirrored database, so the add flow works without the phone nearby. Mirrors the
    /// phone-side `watchConfigAvailableItems` handler; items are stored as `type: .entity`.
    func fetchAvailableItems(
        completion: @escaping (Swift.Result<WatchConfigAvailableItems, WatchConfigEditError>)
            -> Void
    ) {
        let allowedDomains: Set<String> = [
            Domain.script.rawValue,
            Domain.scene.rawValue,
            Domain.automation.rawValue,
        ]
        let magicItemProvider = Current.magicItemProvider()
        magicItemProvider.loadInformation { entitiesPerServer in
            let groups: [WatchConfigAvailableItems.ServerGroup] = Current.servers.all.map { server in
                let serverId = server.identifier.rawValue
                let serverPrefix = "\(server.info.name) • "
                let candidates: [WatchConfigAvailableItems.Candidate] = (entitiesPerServer[serverId] ?? [])
                    .filter { allowedDomains.contains($0.domain) }
                    .compactMap { entity in
                        let item = MagicItem(id: entity.entityId, serverId: serverId, type: .entity)
                        guard let info = magicItemProvider.getInfo(for: item) else { return nil }
                        let context = info.contextSubtitle.map { subtitle in
                            subtitle.hasPrefix(serverPrefix) ? String(subtitle.dropFirst(serverPrefix.count)) : subtitle
                        }
                        return .init(item: item, info: info, contextSubtitle: context)
                    }
                return .init(serverId: serverId, serverName: server.info.name, candidates: candidates)
            }
            DispatchQueue.main.async {
                completion(.success(WatchConfigAvailableItems(servers: groups)))
            }
        }
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
