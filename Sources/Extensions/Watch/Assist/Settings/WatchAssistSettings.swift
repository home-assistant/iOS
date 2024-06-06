import Shared
import SwiftUI

struct WatchAssistSettings: View {
    @EnvironmentObject var assistService: WatchAssistService

    var body: some View {
        ScrollView {
            VStack {
                VStack {
                    Text(L10n.Settings.ConnectionSection.servers)
                    Picker(selection: $assistService.selectedServer) {
                        ForEach($assistService.servers.wrappedValue, id: \.identifier.rawValue) { server in
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

                VStack {
                    Text(L10n.Assist.PipelinesPicker.title)
                    Picker(selection: $assistService.preferredPipeline) {
                        ForEach($assistService.pipelines.wrappedValue, id: \.id) { pipeline in
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
