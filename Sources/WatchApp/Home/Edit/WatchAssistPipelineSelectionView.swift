import SFSafeSymbols
import Shared
import SwiftUI

/// Pipeline chooser for the on-watch Assist prompt flow: one section per server, holding that
/// server's pipelines (its "Preferred" entry first). The server is the section header rather than a
/// prefix on every row, matching the iPhone's Assist pipeline picker.
struct WatchAssistPipelineSelectionView: View {
    let options: [WatchAssistPipelineOption]
    @Binding var selectedOptionId: String?

    @Environment(\.dismiss) private var dismiss

    /// Servers in the order their pipelines were loaded, so the sections don't reshuffle.
    private var serverIds: [String] {
        var seen = Set<String>()
        return options.map(\.serverId).filter { seen.insert($0).inserted }
    }

    var body: some View {
        List {
            ForEach(serverIds, id: \.self) { serverId in
                section(for: options.filter { $0.serverId == serverId })
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Config.Assist.pipeline))
    }

    @ViewBuilder
    private func section(for serverOptions: [WatchAssistPipelineOption]) -> some View {
        Section {
            ForEach(serverOptions) { option in
                Button {
                    selectedOptionId = option.id
                    dismiss()
                } label: {
                    if option.id == selectedOptionId {
                        Label(option.name, systemSymbol: .checkmark)
                    } else {
                        Text(verbatim: option.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } header: {
            if let serverName = serverOptions.first?.serverName {
                Text(verbatim: serverName)
            }
        }
    }
}

#Preview {
    NavigationView {
        WatchAssistPipelineSelectionView(
            options: [
                .init(serverId: "1", serverName: "Home", pipelineId: "", name: "Preferred"),
                .init(serverId: "1", serverName: "Home", pipelineId: "p1", name: "Home Assistant"),
                .init(serverId: "2", serverName: "Cabin", pipelineId: "", name: "Preferred"),
            ],
            selectedOptionId: .constant("1|")
        )
    }
}
