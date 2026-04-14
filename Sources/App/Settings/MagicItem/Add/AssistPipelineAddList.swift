import SFSafeSymbols
import Shared
import SwiftUI

struct AssistPipelineAddList: View {
    @State private var isLoading = false
    @State private var assistConfigs: [AssistPipelines] = []
    @State private var assistServices: [AssistServiceProtocol] = []
    @State private var searchTerm = ""

    let itemToAdd: (MagicItem) -> Void

    var body: some View {
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
                    ForEach(filteredPipelines(config.pipelines), id: \.id) { pipeline in
                        Button {
                            itemToAdd(.init(
                                id: pipeline.id,
                                serverId: config.serverId,
                                type: .assistPipeline
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
        }
    }

    private func filteredPipelines(_ pipelines: [Pipeline]) -> [Pipeline] {
        if searchTerm.count > 2 {
            return pipelines.filter { $0.name.lowercased().contains(searchTerm.lowercased()) }
        }
        return pipelines
    }

    private func serverName(serverId: String) -> String {
        Current.servers.all.first(where: { $0.identifier.rawValue == serverId })?.info.name ?? serverId
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
