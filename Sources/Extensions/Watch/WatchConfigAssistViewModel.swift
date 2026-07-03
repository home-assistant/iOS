import Communicator
import Foundation
import Shared
import SwiftUI

final class WatchConfigAssistViewModel: ObservableObject {
    struct PipelineOption: Identifiable, Hashable {
        let id: String
        let name: String
    }

    @Published var showAssist: Bool
    @Published var selectedServerId: String?
    @Published var selectedPipelineId: String?
    @Published var pipelines: [PipelineOption] = []
    @Published var isLoadingPipelines = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    let servers: [Server]

    var isPhoneReachable: Bool {
        Communicator.shared.currentReachability == .immediatelyReachable
    }

    private var selectedPipelineName: String? {
        guard showAssist, selectedPipelineId != nil else { return nil }
        guard selectedPipelineId != "" else { return L10n.Watch.Config.Assist.preferred }
        return pipelines.first(where: { $0.id == selectedPipelineId })?.name
    }

    init() {
        let resolved = ((try? WatchConfig.config()) ?? nil) ?? WatchConfig()
        self.showAssist = resolved.assist.showAssist
        self.selectedServerId = resolved.assist.serverId
        self.selectedPipelineId = resolved.assist.pipelineId
        self.servers = Current.servers.all
        if selectedServerId == nil {
            self.selectedServerId = servers.first?.identifier.rawValue
        }
    }

    /// Local-first: show the pipelines the phone already mirrored to the watch's GRDB (instant, works
    /// offline). Only reach out to the phone when nothing is cached yet and it's reachable.
    @MainActor
    func loadPipelines() {
        guard let serverId = selectedServerId else {
            pipelines = []
            return
        }
        loadPipelinesFromMirror(serverId: serverId)
        if pipelines.isEmpty, isPhoneReachable {
            refreshFromPhone()
        }
    }

    /// Force a fresh fetch from the paired iPhone (the Reload button). Keeps the cached list on failure
    /// so a transient connection hiccup doesn't blank the picker.
    @MainActor
    func refreshFromPhone() {
        guard let serverId = selectedServerId else { return }
        guard isPhoneReachable else {
            loadPipelinesFromMirror(serverId: serverId)
            return
        }
        isLoadingPipelines = true
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.assistPipelinesFetch.rawValue,
            content: ["serverId": serverId],
            reply: { [weak self] message in
                Task { @MainActor in self?.handlePipelinesResponse(message) }
            }
        ), errorHandler: { [weak self] error in
            Current.Log.error("Failed to fetch assist pipelines on watch: \(error.localizedDescription)")
            Task { @MainActor in
                self?.isLoadingPipelines = false
                self?.loadPipelinesFromMirror(serverId: serverId)
            }
        })
    }

    /// Populate the picker from the locally-mirrored `AssistPipelines` table (works offline).
    @MainActor
    private func loadPipelinesFromMirror(serverId: String) {
        let mirrored = ((try? AssistPipelines.config()) ?? nil) ?? []
        pipelines = mirrored
            .first(where: { $0.serverId == serverId })?
            .pipelines
            .map { PipelineOption(id: $0.id, name: $0.name) } ?? []
        applyDefaultPipelineSelection()
    }

    @MainActor
    private func handlePipelinesResponse(_ message: ImmediateMessage) {
        isLoadingPipelines = false
        guard let raw = message.content["pipelines"] as? [[String: String]] else {
            if let serverId = selectedServerId {
                loadPipelinesFromMirror(serverId: serverId)
            }
            return
        }
        pipelines = raw.compactMap { dict in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return PipelineOption(id: id, name: name)
        }
        applyDefaultPipelineSelection()
    }

    /// Default to "Preferred" (empty id) — the server chooses the pipeline — and fall back to it if a
    /// previously-selected pipeline no longer exists. Only reset when we actually have a list to check
    /// against, so an empty/offline cache doesn't wipe the saved selection.
    @MainActor
    private func applyDefaultPipelineSelection() {
        if selectedPipelineId == nil {
            selectedPipelineId = ""
        } else if selectedPipelineId != "", !pipelines.isEmpty,
                  !pipelines.contains(where: { $0.id == selectedPipelineId }) {
            selectedPipelineId = ""
        }
    }

    @MainActor
    func save(completion: @escaping @MainActor (Bool) -> Void) {
        var config = ((try? WatchConfig.config()) ?? nil) ?? WatchConfig()
        config.assist = .init(
            showAssist: showAssist,
            serverId: showAssist ? selectedServerId : nil,
            pipelineId: showAssist ? selectedPipelineId : nil
        )
        config.stampModified()
        // Persist locally first so the change survives even without the phone nearby.
        persistLocally(config)
        WatchUserDefaults.shared.assistPipelineName = selectedPipelineName
        NotificationCenter.default.post(name: .watchConfigDidChange, object: nil)

        // Offline: keep the local edit; it syncs (or prompts on conflict) on the next reload.
        guard isPhoneReachable else {
            completion(true)
            return
        }
        isSaving = true
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfigUpdate.rawValue,
            content: ["config": config.encodeForWatch()],
            reply: { [weak self] message in
                Task { @MainActor in
                    self?.handleSaveResponse(message, completion: completion)
                }
            }
        ), errorHandler: { [weak self] error in
            Current.Log.error("Failed to save assist config on watch: \(error.localizedDescription)")
            Task { @MainActor in
                self?.isSaving = false
                // The local copy is already saved; it'll sync on the next reload.
                completion(true)
            }
        })
    }

    private func persistLocally(_ config: WatchConfig) {
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
            Current.Log.error("Failed to persist assist config locally on watch: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func handleSaveResponse(
        _ message: ImmediateMessage,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        defer { isSaving = false }

        guard message.identifier == InteractiveImmediateResponses.watchConfigResponse.rawValue,
              let configData = message.content["config"] as? Data,
              let config = WatchConfig.decodeForWatch(configData),
              let magicItemsInfoData = message.content["magicItemsInfo"] as? [Data] else {
            Current.Log.error("Failed to decode assist config save response on watch")
            // The local copy is already saved; it'll sync on the next reload.
            completion(true)
            return
        }

        let magicItemsInfo = magicItemsInfoData.compactMap { MagicItem.Info.decodeForWatch($0) }

        persistLocally(config)
        saveItemsInfoInCache(magicItemsInfo)
        // The phone accepted our push, so this is now the synced baseline.
        WatchUserDefaults.shared.lastSyncedModified = config.lastModified
        WatchUserDefaults.shared.assistPipelineName = selectedPipelineName
        NotificationCenter.default.post(name: .watchConfigDidChange, object: nil)
        completion(true)
    }

    private func saveItemsInfoInCache(_ itemsInfo: [MagicItem.Info]) {
        do {
            let jsonData = try JSONEncoder().encode(itemsInfo)
            try jsonData.write(to: AppConstants.watchMagicItemsInfo)
        } catch {
            Current.Log.error("Error saving JSON for magic items info: \(error)")
        }
    }
}
