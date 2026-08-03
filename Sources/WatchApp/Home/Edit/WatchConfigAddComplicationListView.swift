import Shared
import SwiftUI

/// The on-watch list of complications that can be added to the item list, read straight from the
/// mirrored database so the flow works with the iPhone out of range.
///
/// Adding one commits immediately: unlike an entity there is nothing to name or recolor — the
/// complication already carries its own configuration, made on the iPhone.
struct WatchConfigAddComplicationListView: View {
    let viewModel: WatchHomeViewModel
    /// When set, the complication goes into this folder instead of the root.
    let folderId: String?
    let finish: () -> Void

    /// `nil` until the first load finishes, which is what puts the spinner on screen.
    @State private var complications: [WatchComplicationConfig]?

    var body: some View {
        Group {
            if complications == nil {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if complications?.isEmpty ?? true {
                List {
                    Text(verbatim: L10n.Watch.Config.Add.complicationsEmpty)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(complications ?? [], id: \.id) { config in
                        Button {
                            add(config)
                        } label: {
                            row(for: config)
                        }
                        .watchHomeItemRowStyle(tint: nil)
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Config.Add.complication))
        .onAppear(perform: load)
    }

    private func row(for config: WatchComplicationConfig) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Text(verbatim: config.displayName)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let subtitle = config.entityDisplayName ?? config.entityId {
                Text(verbatim: subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() {
        // Kept once loaded: the mirror doesn't change while the sheet is open, and reloading on the
        // way back from a deeper screen would swap the list for a spinner again.
        guard complications == nil else { return }
        do {
            complications = try WatchComplicationConfig.watchListAddable()
        } catch {
            Current.Log.error("Failed to load watch complications: \(error.localizedDescription)")
            complications = []
        }
    }

    private func add(_ config: WatchComplicationConfig) {
        let item = MagicItem(complication: config)
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
    NavigationView {
        WatchConfigAddComplicationListView(viewModel: WatchHomeViewModel(), folderId: nil, finish: {})
    }
}
