import Shared
import SwiftUI

/// Area layer of the watch add flow: resolves the addable areas from the mirrored database and
/// either shows the server picker (multiple servers have areas) or jumps straight to the only
/// server's area list. Mirrors the entity flow's source screen, including keeping a finished load
/// so navigating back doesn't rebuild it.
struct WatchConfigAddAreaSourceView: View {
    /// Held without `@ObservedObject` for the same reason as the entity flow: this screen only calls
    /// the view model and renders none of its published state.
    let viewModel: WatchHomeViewModel
    /// When set, the added area goes into this folder instead of the root.
    let folderId: String?
    let finish: () -> Void

    /// `nil` until the first load finishes, which is what puts the spinner on screen.
    @State private var groups: [WatchAddableAreaGroup]?
    /// Guards against a second fetch while one is already running (`onAppear` can fire more than once).
    @State private var isFetching = false

    var body: some View {
        Group {
            if let groups {
                if groups.isEmpty {
                    List {
                        Text(verbatim: L10n.Watch.Config.Add.noAreas)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if groups.count == 1, let group = groups.first {
                    areaList(for: group)
                } else {
                    List {
                        ForEach(groups) { group in
                            NavigationLink {
                                areaList(for: group)
                            } label: {
                                Text(verbatim: group.serverName)
                            }
                        }
                    }
                    .navigationTitle(Text(verbatim: L10n.Watch.Config.Assist.selectServer))
                }
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .onAppear(perform: load)
    }

    private func areaList(for group: WatchAddableAreaGroup) -> some View {
        WatchConfigAddAreaListView(
            group: group,
            viewModel: viewModel,
            folderId: folderId,
            finish: finish
        )
    }

    private func load() {
        guard groups == nil, !isFetching else { return }
        isFetching = true
        viewModel.fetchAvailableAreas { resolved in
            groups = resolved
            isFetching = false
        }
    }
}

#Preview {
    MaterialDesignIcons.register()
    return NavigationView {
        WatchConfigAddAreaSourceView(
            viewModel: WatchHomeViewModel(),
            folderId: nil,
            finish: {}
        )
    }
}
