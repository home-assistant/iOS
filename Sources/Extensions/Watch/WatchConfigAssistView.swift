import Communicator
import Foundation
import Shared
import SwiftUI

/// Configure the watch Assist button (whether it shows, and which server + pipeline it uses) directly
/// on the watch. Self-contained: it reads the current config from the local cache, fetches pipelines
/// from the paired iPhone, and persists via the shared `watchConfigUpdate` round-trip.
struct WatchConfigAssistView: View {
    @StateObject private var viewModel = WatchConfigAssistViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Toggle(isOn: $viewModel.showAssist) {
                    Text(verbatim: L10n.Watch.Config.Assist.show)
                }
            }

            if viewModel.showAssist {
                if viewModel.servers.count > 1 {
                    Section {
                        Picker(L10n.Watch.Config.Assist.selectServer, selection: $viewModel.selectedServerId) {
                            ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                                Text(verbatim: server.info.name)
                                    .tag(Optional(server.identifier.rawValue))
                            }
                        }
                        .onChange(of: viewModel.selectedServerId) { _ in
                            viewModel.selectedPipelineId = nil
                            viewModel.fetchPipelines()
                        }
                    }
                }

                Section {
                    if viewModel.isLoadingPipelines {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if viewModel.pipelines.isEmpty {
                        Text(verbatim: L10n.Watch.Config.Assist.Error.fetchFailed)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(L10n.Watch.Config.Assist.pipeline, selection: $viewModel.selectedPipelineId) {
                            Text(verbatim: L10n.Watch.Config.Assist.preferred)
                                .tag(Optional(""))
                            ForEach(viewModel.pipelines) { pipeline in
                                Text(verbatim: pipeline.name)
                                    .tag(Optional(pipeline.id))
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    viewModel.save { success in
                        if success { dismiss() }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text(verbatim: L10n.Watch.Config.Assist.save)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .disabled(viewModel.isSaving)
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Config.Assist.title))
        .onAppear {
            if viewModel.showAssist {
                viewModel.fetchPipelines()
            }
        }
        .alert(
            Text(verbatim: L10n.Watch.Config.Assist.title),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(verbatim: errorMessage)
            }
        }
    }
}

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
    private let currentItems: [MagicItem]

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
        self.currentItems = resolved.items
        self.servers = Current.servers.all
        if selectedServerId == nil {
            self.selectedServerId = servers.first?.identifier.rawValue
        }
    }

    @MainActor
    func fetchPipelines() {
        guard let serverId = selectedServerId, isPhoneReachable else {
            pipelines = []
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
                self?.errorMessage = L10n.Watch.Config.Assist.Error.fetchFailed
            }
        })
    }

    @MainActor
    private func handlePipelinesResponse(_ message: ImmediateMessage) {
        isLoadingPipelines = false
        guard let raw = message.content["pipelines"] as? [[String: String]] else {
            errorMessage = L10n.Watch.Config.Assist.Error.fetchFailed
            return
        }
        pipelines = raw.compactMap { dict in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return PipelineOption(id: id, name: name)
        }
        // Default to "Preferred" (empty id): the server chooses the pipeline. Also fall back to
        // Preferred if a previously-selected pipeline no longer exists.
        if selectedPipelineId == nil {
            selectedPipelineId = ""
        } else if selectedPipelineId != "", !pipelines.contains(where: { $0.id == selectedPipelineId }) {
            selectedPipelineId = ""
        }
    }

    @MainActor
    func save(completion: @escaping @MainActor (Bool) -> Void) {
        guard isPhoneReachable else {
            errorMessage = L10n.Watch.Config.Edit.Error.notReachable
            completion(false)
            return
        }
        var config = WatchConfig()
        config.items = currentItems
        config.assist = .init(
            showAssist: showAssist,
            serverId: showAssist ? selectedServerId : nil,
            pipelineId: showAssist ? selectedPipelineId : nil
        )
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
                self?.errorMessage = L10n.Watch.Config.Edit.Error.saveFailed
                completion(false)
            }
        })
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
            errorMessage = L10n.Watch.Config.Edit.Error.saveFailed
            completion(false)
            return
        }

        let magicItemsInfo = magicItemsInfoData.compactMap { MagicItem.Info.decodeForWatch($0) }

        do {
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            saveItemsInfoInCache(magicItemsInfo)
            WatchUserDefaults.shared.assistPipelineName = selectedPipelineName
            NotificationCenter.default.post(name: .watchConfigDidChange, object: nil)
            completion(true)
        } catch {
            Current.Log.error("Failed to save assist config cache on watch: \(error.localizedDescription)")
            errorMessage = L10n.Watch.Config.Edit.Error.saveFailed
            completion(false)
        }
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

extension Notification.Name {
    static let watchConfigDidChange = Notification.Name("watchConfigDidChange")
}
