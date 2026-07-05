import Communicator
import Foundation
import Shared
import SwiftUI

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
