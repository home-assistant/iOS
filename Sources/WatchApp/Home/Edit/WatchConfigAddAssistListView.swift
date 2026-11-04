import Shared
import SwiftUI

/// The on-watch list of Assist pipelines that can be added as items, read from the mirrored
/// database so the flow works with the iPhone out of range. Picking one commits immediately —
/// there is nothing else to configure, and the name and icon can be changed afterwards from the
/// item's edit screen.
struct WatchConfigAddAssistListView: View {
    let viewModel: WatchHomeViewModel
    /// When set, the pipeline goes into this folder instead of the root.
    let folderId: String?
    let finish: () -> Void

    /// `nil` until the first load finishes, which is what puts the spinner on screen.
    @State private var options: [WatchAssistPipelineOption]?

    private var groupedOptions: [String: [WatchAssistPipelineOption]] {
        Dictionary(grouping: options ?? [], by: \.serverId)
    }

    private var showsServerHeaders: Bool {
        groupedOptions.count > 1
    }

    var body: some View {
        Group {
            if options == nil {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if options?.isEmpty ?? true {
                List {
                    Text(verbatim: L10n.Watch.Config.Assist.noPipelines)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(groupedOptions.keys.sorted(), id: \.self) { serverId in
                        section(for: groupedOptions[serverId] ?? [])
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Widgets.Action.Name.assist))
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func section(for serverOptions: [WatchAssistPipelineOption]) -> some View {
        Section {
            // Plain rows, like the add flow's other pickers: the home screen's row style is
            // full-bleed and would push the text under the screen's edge here.
            ForEach(serverOptions) { option in
                Button {
                    add(option)
                } label: {
                    Text(verbatim: option.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } header: {
            if showsServerHeaders, let serverName = serverOptions.first?.serverName {
                Text(verbatim: serverName)
            }
        }
    }

    private func load() {
        // Kept once loaded: the mirror doesn't change while the sheet is open.
        guard options == nil else { return }
        options = WatchAssistPipelineOption.all()
    }

    private func add(_ option: WatchAssistPipelineOption) {
        let item = option.makePipelineItem()
        let info = Current.magicItemProvider().getInfo(for: item)
        if let folderId {
            viewModel.addItemToFolder(folderId: folderId, item: item, info: info)
        } else {
            viewModel.addItem(item, info: info)
        }
        viewModel.saveConfig()
        finish()
    }
}

#Preview {
    MaterialDesignIcons.register()
    return NavigationView {
        WatchConfigAddAssistListView(viewModel: WatchHomeViewModel(), folderId: nil, finish: {})
    }
}
