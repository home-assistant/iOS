import SFSafeSymbols
import Shared
import SwiftUI

/// Area picker the vacuum controls screen navigates to: the areas an administrator mapped to the
/// vacuum's segments, tapped in the order they should be cleaned (the frontend numbers the
/// selection the same way), then started with `vacuum.clean_area`.
///
/// The area list comes from the paired iPhone — the mapping lives in the entity registry, which
/// Home Assistant serves over WebSocket only, and the watch has no WebSocket. The controls screen
/// only offers this when the phone is reachable, and this screen handles it going away mid-use.
struct WatchVacuumCleanAreasView: View {
    @ObservedObject var viewModel: WatchVacuumControlsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if viewModel.isLoadingAreas {
                loading
            } else if viewModel.cleanableAreas.isEmpty {
                empty
            } else {
                areas
                startButton
            }
        }
        .navigationTitle(Text(verbatim: L10n.Vacuum.Control.CleanAreas.title))
        .onAppear {
            viewModel.loadCleanableAreas()
        }
    }

    private var loading: some View {
        VStack(spacing: DesignSystem.Spaces.half) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(verbatim: L10n.Watch.EntityDetails.loading)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }

    private var empty: some View {
        // Either nothing is mapped yet, or the phone stopped answering mid-flight. Both are
        // resolved elsewhere (the frontend / bringing the phone closer), so just say so.
        Text(
            verbatim: viewModel.isPhoneReachable
                ? L10n.Vacuum.Control.CleanAreas.empty
                : L10n.Vacuum.Control.CleanAreas.needsPhone
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }

    private var areas: some View {
        ForEach(viewModel.cleanableAreas, id: \.id) { area in
            Button {
                viewModel.toggleAreaSelection(area.id)
            } label: {
                HStack {
                    Text(verbatim: area.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let order = viewModel.selectionOrder(of: area.id) {
                        // The number is the cleaning order, matching the frontend's badge.
                        Text(verbatim: "\(order)")
                            .font(.caption2.bold())
                            .foregroundStyle(.haPrimary)
                    }
                }
            }
        }
    }

    private var startButton: some View {
        Button {
            viewModel.startCleaningSelectedAreas()
            dismiss()
        } label: {
            Label {
                Text(verbatim: L10n.Vacuum.Control.CleanAreas.start("\(viewModel.selectedAreaIds.count)"))
            } icon: {
                Image(systemSymbol: .playFill)
            }
        }
        .disabled(viewModel.selectedAreaIds.isEmpty)
    }
}

#Preview {
    MaterialDesignIcons.register()
    let item = MagicItem(id: "vacuum.downstairs", serverId: "1", type: .entity)
    let info = MagicItem.Info(
        id: "1-vacuum.downstairs",
        name: "Downstairs vacuum",
        iconName: "mdi:robot-vacuum"
    )
    return NavigationStack {
        WatchVacuumCleanAreasView(viewModel: .init(item: item, itemInfo: info))
    }
}
