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
    /// Server used to filter the list inside the sheet (separate from the committed `selectedServerId`).
    @State private var filterServerId: String?

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
                    if Current.servers.all.count > 1 {
                        EntityFilterPickerView(
                            title: L10n.EntityPicker.Filter.Server.title,
                            pickerItems: Current.servers.all
                                .sorted(by: { $0.info.sortOrder < $1.info.sortOrder })
                                .map { EntityFilterPickerView.PickerItem(
                                    id: $0.identifier.rawValue,
                                    title: $0.info.name
                                ) },
                            selectedItemId: $filterServerId
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    if isLoading {
                        Section {
                            HStack {
                                Spacer()
                                HAProgressView()
                                Spacer()
                            }
                            .padding()
                        }
                    } else if filteredConfig?.pipelines.isEmpty ?? true {
                        Section {
                            Text(L10n.AssistPipelinePicker.noPipelines)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let filteredConfig {
                        Section {
                            ForEach(filteredPipelines(filteredConfig.pipelines), id: \.id) { pipeline in
                                Button(action: {
                                    selectedPipelineId = pipeline.id
                                    selectedServerId = filteredConfig.serverId
                                    showList = false
                                }, label: {
                                    if selectedPipelineId == pipeline.id, selectedServerId == filteredConfig.serverId {
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
                    if filterServerId == nil {
                        filterServerId = selectedServerId ?? Current.servers.all.first?.identifier.rawValue
                    }
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

    private var filteredConfig: AssistPipelines? {
        assistConfigs.first(where: { $0.serverId == filterServerId })
    }

    private func filteredPipelines(_ pipelines: [Pipeline]) -> [Pipeline] {
        if searchTerm.count > 2 {
            return pipelines.filter { $0.name.lowercased().contains(searchTerm.lowercased()) }
        }
        return pipelines
    }

    private func nameForSelectedPipeline() -> String? {
        guard let selectedServerId, let selectedPipelineId else { return nil }
        return assistConfigs.first(where: { $0.serverId == selectedServerId })?.pipelines
            .first(where: { $0.id == selectedPipelineId })?.name
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
