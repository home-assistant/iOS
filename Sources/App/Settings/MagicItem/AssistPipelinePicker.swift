import SFSafeSymbols
import Shared
import SwiftUI

struct AssistPipelinePicker: View {
    /// Returns serverId and selected pipeline
    let action: (String, Pipeline) -> Void

    init(action: @escaping (String, Pipeline) -> Void) {
        self.action = action
    }

    @State private var showList = false
    @State private var assistConfigs: [AssistPipelines] = []
    @State private var selectedPipeline: Pipeline?
    @State private var searchTerm = ""

    var body: some View {
        Button(action: {
            showList = true
        }, label: {
            Text(selectedPipeline?.name ?? L10n.AssistPipelinePicker.placeholder)
        })
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
                                    selectedPipeline = pipeline
                                    action(config.serverId, pipeline)
                                    showList = false
                                }, label: {
                                    if selectedPipeline?.id == pipeline.id {
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
