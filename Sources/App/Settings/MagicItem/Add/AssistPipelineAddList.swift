import SFSafeSymbols
import Shared
import SwiftUI

struct AssistPipelineAddList: View {
    @State private var isLoading = false
    @State private var assistConfigs: [AssistPipelines] = []
    @State private var assistServices: [AssistServiceProtocol] = []
    @State private var searchTerm = ""
    @State private var selectedServerId: String?

    let itemToAdd: (MagicItem) -> Void

    var body: some View {
        List {
            if Current.servers.all.count > 1 {
                serverPicker
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
            } else if selectedConfig?.pipelines.isEmpty ?? true {
                Section {
                    Text(L10n.AssistPipelinePicker.noPipelines)
                        .foregroundColor(.secondary)
                }
            }

            if let selectedConfig {
                Section {
                    ForEach(filteredPipelines(selectedConfig.pipelines), id: \.id) { pipeline in
                        Button {
                            itemToAdd(.init(
                                id: pipeline.id,
                                serverId: selectedConfig.serverId,
                                type: .assistPipeline,
                                customization: .init(iconColor: MagicItem.defaultAssistIconColorHex)
                            ))
                        } label: {
                            HStack {
                                Image(
                                    uiImage: MaterialDesignIcons.microphoneIcon.image(
                                        ofSize: .init(width: 18, height: 18),
                                        color: .accent
                                    )
                                )
                                Text(pipeline.name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemSymbol: .plusCircleFill)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .tint(Color(uiColor: .label))
                    }
                }
            }
        }
        .searchable(text: $searchTerm)
        .onAppear {
            fetchPipelines()
            if selectedServerId == nil {
                selectedServerId = Current.servers.all.first?.identifier.rawValue
            }
        }
    }

    private var selectedConfig: AssistPipelines? {
        assistConfigs.first(where: { $0.serverId == selectedServerId })
    }

    @ViewBuilder
    private var serverPicker: some View {
        EntityFilterPickerView(
            title: L10n.EntityPicker.Filter.Server.title,
            pickerItems: Current.servers.all
                .sorted(by: { $0.info.sortOrder < $1.info.sortOrder })
                .map { EntityFilterPickerView.PickerItem(id: $0.identifier.rawValue, title: $0.info.name) },
            selectedItemId: $selectedServerId
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func filteredPipelines(_ pipelines: [Pipeline]) -> [Pipeline] {
        if searchTerm.count > 2 {
            return pipelines.filter { $0.name.lowercased().contains(searchTerm.lowercased()) }
        }
        return pipelines
    }

    private func fetchPipelines() {
        do {
            assistConfigs = try AssistPipelines.config() ?? []
            if assistConfigs.isEmpty {
                requestPipelines()
            }
        } catch {
            Current.Log.error("Failed to fetch assist pipelines: \(error)")
            requestPipelines()
        }
    }

    private func requestPipelines() {
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
                Current.Log.error("Failed to fetch assist pipelines after server fetch: \(error)")
            }
        }
    }
}
