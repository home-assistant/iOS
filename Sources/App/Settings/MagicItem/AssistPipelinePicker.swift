import SFSafeSymbols
import Shared
import SwiftUI

struct AssistPipelinePicker: View {
    /// Returns serverId and selected pipeline
    @State private var showList = false
    @State private var isLoading = false
    @State private var assistConfigs: [AssistPipelines] = []
    @Binding private var selectedServerId: String?
    @Binding private var selectedPipelineId: String?
    @State private var searchTerm = ""

    @State private var assistServices: [AssistServiceProtocol] = []

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
                    if isLoading {
                        Section {
                            HStack {
                                Spacer()
                                HAProgressView()
                                Spacer()
                            }
                            .padding()
                        }
                    } else if assistConfigs.isEmpty {
                        Section {
                            Text(L10n.AssistPipelinePicker.noPipelines)
                                .foregroundColor(.secondary)
                        }
                    }

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
                .navigationViewStyle(.stack)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton {
                            showList = false
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            requestPipelines()
                        }, label: {
                            Image(systemSymbol: .arrowClockwise)
                        })
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
            if assistConfigs.isEmpty {
                requestPipelines()
            }
        } catch {
            Current.Log.error("Failed to fetch assist pipelines for assist pipeline picker, error: \(error)")
            requestPipelines()
        }
    }

    private func requestPipelines() {
        Current.Log.info("No assist pipelines available in database requesting fetch from servers")
        isLoading = true

        let group = DispatchGroup()

        for server in Current.servers.all {
            group.enter()
            let assistService = AssistService(server: server)
            assistServices.append(assistService)
            assistService.fetchPipelines { _ in
                group.leave()
            }
        }

        group.notify(queue: .main) {
            isLoading = false
            assistServices = []
            do {
                assistConfigs = try AssistPipelines.config() ?? []
            } catch {
                Current.Log
                    .error(
                        "Failed to fetch assist pipelines after server fetch, error: \(error)"
                    )
            }
        }
    }
}
