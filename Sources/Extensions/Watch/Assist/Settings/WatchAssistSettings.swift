import Shared
import SwiftUI

struct WatchAssistSettings: View {
    @StateObject private var assistService: WatchAssistService

    init(assistService: WatchAssistService) {
        self._assistService = .init(wrappedValue: assistService)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spaces.two) {
                if !assistService.servers.isEmpty, assistService.selectedServer != nil {
                    VStack {
                        Text(L10n.Settings.ConnectionSection.servers)
                        Picker(selection: $assistService.selectedServer) {
                            ForEach(assistService.servers, id: \.identifier.rawValue) { server in
                                Text(server.info.name)
                                    .tag(server.identifier.rawValue)
                            }
                        } label: {
                            EmptyView()
                        }
                        .modify {
                            if #available(watchOS 9, *) {
                                $0.pickerStyle(.navigationLink)
                            } else {
                                $0.pickerStyle(.wheel)
                                    .frame(height: 100)
                            }
                        }
                    }
                }
                if !assistService.isFetchingPipeline, !assistService.pipelines.isEmpty {
                    VStack {
                        Text(L10n.Assist.PipelinesPicker.title)
                        Picker(selection: $assistService.preferredPipeline) {
                            ForEach(assistService.pipelines, id: \.id) { pipeline in
                                Text(pipeline.name)
                                    .tag(pipeline.id)
                            }
                        } label: {
                            EmptyView()
                        }
                        .modify {
                            if #available(watchOS 9, *) {
                                $0.pickerStyle(.navigationLink)
                            } else {
                                $0.pickerStyle(.wheel)
                                    .frame(height: 100)
                            }
                        }
                    }
                }
            }
        }
    }
}
