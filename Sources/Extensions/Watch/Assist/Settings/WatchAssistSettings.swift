import AVFAudio
import MediaPlayer
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
                HStack {
                    Text(L10n.Assist.Watch.Volume.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VolumeView()
                }
                .padding()
                .background(.gray.opacity(0.2))
                .modify({ view in
                    if #available(watchOS 10, *) {
                        view.background(.ultraThinMaterial)
                    } else {
                        view
                    }
                })
                .clipShape(RoundedRectangle(cornerRadius: 35))
                .padding(.top)
                if !assistService.servers.isEmpty {
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
