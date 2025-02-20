import SFSafeSymbols
import Shared
import SwiftUI

struct AssistPipelinePicker: View {
    /// Returns serverId and selected pipeline
    @State private var showList = false
    @State private var assistConfigs: [AssistPipelines] = []
    @Binding private var selectedServerId: String?
    @Binding private var selectedPipelineId: String?
    @State private var searchTerm = ""

    init(selectedServerId: Binding<String?>, selectedPipelineId: Binding<String?>) {
        self._selectedServerId = selectedServerId
        self._selectedPipelineId = selectedPipelineId
    }

    var body: some View {
        Button(action: {
            showList = true
        }, label: {
            if selectedServerId != nil, let selectedPipelineId, !assistConfigs.isEmpty {
                Text(nameForSelectedPipeline() ?? selectedPipelineId)
            } else {
                Text(verbatim: L10n.AssistPipelinePicker.placeholder)
            }
        })
        .onAppear {
            fetchPipelines()
        }
        .sheet(isPresented: $showList) {
            NavigationView {
                List {
                    ForEach(assistConfigs, id: \.serverId) { config in
                        Section(serverName(serverId: config.serverId)) {
                            ForEach(config.pipelines.filter({ pipeline in
                                if searchTerm.count > 2 {
                                    return pipeline.name.lowercased().contains(searchTerm.lowercased())
                                } else {
                                    return true
                                }
                            }), id: \.id) { pipeline in
                                Button(action: {
                                    selectedPipelineId = pipeline.id
                                    selectedServerId = config.serverId
                                    showList = false
                                }, label: {
                                    if selectedPipelineId == pipeline.id, selectedServerId == config.serverId {
                                        Label(pipeline.name, systemSymbol: .checkmark)
                                    } else {
                                        Text(pipeline.name)
                                    }
                                })
                                .tint(.accentColor)
                            }
                        }
                    }
                }
                .searchable(text: $searchTerm)
                .onAppear {
                    fetchPipelines()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        CloseButton {
                            showList = false
                        }
                    }
                }
            }
        }
    }

    private func nameForSelectedPipeline() -> String? {
        guard let selectedServerId, let selectedPipelineId else { return nil }
        return assistConfigs.first(where: { $0.serverId == selectedServerId })?.pipelines
            .first(where: { $0.id == selectedPipelineId })?.name
    }

    private func serverName(serverId: String) -> String {
        Current.servers.all.first(where: { server in
            server.identifier.rawValue == serverId
        })?.info.name ?? "Unknown server"
    }

    private func fetchPipelines() {
        do {
            assistConfigs = try AssistPipelines.config() ?? []
        } catch {
            Current.Log.error("Failed to fetch assist pipelines for assist pipeline picker, error: \(error)")
        }
    }
}
