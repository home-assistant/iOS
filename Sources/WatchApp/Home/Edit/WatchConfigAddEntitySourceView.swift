import Shared
import SwiftUI

/// Entity layer of the watch add flow: resolves the addable entities from the mirrored database and
/// either shows the server picker (multiple servers) or jumps straight to the area filter (single
/// server). The result is loaded once and kept for the lifetime of the flow — the mirror doesn't
/// change while the sheet is open.
struct WatchConfigAddEntitySourceView: View {
    /// Held without `@ObservedObject` on purpose: the add flow only *calls* the view model (fetch and
    /// mutate) and renders none of its published state.
    let viewModel: WatchHomeViewModel
    /// When set, added items go into this folder instead of the root.
    let folderId: String?
    let finish: () -> Void

    /// `nil` until the first load finishes, which is what puts the spinner on screen. Everything the
    /// build can't resolve — an unreadable or not-yet-synced mirror included — comes back as no
    /// candidates, which the empty state below covers.
    @State private var available: WatchConfigAvailableItems?
    /// Guards against a second fetch while one is already running (`onAppear` can fire more than once).
    @State private var isFetching = false

    private var groups: [WatchConfigAvailableItems.ServerGroup] {
        (available?.servers ?? []).filter { !$0.candidates.isEmpty }
    }

    var body: some View {
        Group {
            if available == nil {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if groups.isEmpty {
                List {
                    Text(verbatim: L10n.Watch.Config.Add.empty)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if groups.count == 1, let group = groups.first {
                areaFilter(for: group)
            } else {
                List {
                    ForEach(groups, id: \.serverId) { group in
                        NavigationLink {
                            areaFilter(for: group)
                        } label: {
                            Text(verbatim: group.serverName)
                        }
                    }
                }
                .navigationTitle(Text(verbatim: L10n.Watch.Config.Assist.selectServer))
            }
        }
        .onAppear(perform: load)
    }

    private func areaFilter(for group: WatchConfigAvailableItems.ServerGroup) -> some View {
        WatchConfigAddEntityAreaFilterView(
            group: group,
            viewModel: viewModel,
            folderId: folderId,
            finish: finish
        )
    }

    private func load() {
        // `onAppear` fires again every time the user navigates back to this screen from a deeper one.
        // Re-fetching there swapped the loaded list back to a spinner and rebuilt every candidate from
        // the database just to show the same rows again, so a finished load is kept.
        guard available == nil, !isFetching else { return }
        isFetching = true
        viewModel.fetchAvailableItems { items in
            available = items
            isFetching = false
        }
    }
}

#Preview {
    MaterialDesignIcons.register()
    return NavigationView {
        WatchConfigAddEntitySourceView(
            viewModel: WatchHomeViewModel(),
            folderId: nil,
            finish: {}
        )
    }
}
