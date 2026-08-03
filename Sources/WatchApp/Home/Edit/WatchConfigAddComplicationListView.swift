import HAWatchComplications
import Shared
import SwiftUI

/// The on-watch list of complications that can be added to the item list, read straight from the
/// mirrored database so the flow works with the iPhone out of range.
///
/// Each row *is* the complication, drawn by the same view the watch face and the item list use, so
/// the choice is made by looking at the thing itself rather than at its name. The values come from
/// the last stored snapshot rather than a fresh fetch: opening a picker must not fire one network
/// round trip per row, and the last thing the face showed is exactly "how it looks".
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
    /// Rectangular layouts to preview, keyed by complication id. Read once with the configs — a
    /// complication with no entry has never been rendered on this watch, and falls back to its name.
    @State private var previews: [String: RectangularComplicationRenderModel] = [:]

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
                        // Plain rows, like the add flow's server picker: the home screen's row style
                        // is full-bleed (zero horizontal insets) and would push the text under the
                        // screen's edge here.
                        Button {
                            add(config)
                        } label: {
                            row(for: config)
                        }
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Config.Add.complication))
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func row(for config: WatchComplicationConfig) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            // The `#available` check stands alone rather than being combined with the lookup: SwiftUI
            // only narrows a branch's availability when the condition is nothing but `#available`.
            if #available(watchOS 10.0, *) {
                if let model = previews[config.id] {
                    RectangularComplicationContentView(model: model)
                } else {
                    unrenderedLabel(for: config)
                }
            } else {
                unrenderedLabel(for: config)
            }
            // The complication's own name, which the face itself never shows — it labels the
            // complication in lists, while the face shows the entity's name. Without it two
            // complications on the same entity would be indistinguishable here.
            Text(verbatim: config.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Stand-in for the complication's layout: shown on watchOS 9, which has no accessory-family
    /// rendering, and for a complication this watch has never rendered — so the row still says what
    /// it is instead of collapsing to just the name below.
    private func unrenderedLabel(for config: WatchComplicationConfig) -> some View {
        Text(verbatim: config.entityDisplayName ?? config.entityId ?? config.displayName)
            .lineLimit(1)
    }

    private func load() {
        // Kept once loaded: the mirror doesn't change while the sheet is open, and reloading on the
        // way back from a deeper screen would swap the list for a spinner again.
        guard complications == nil else { return }
        previews = WatchWidgetComplicationSnapshotStore.storedSnapshots()
            .compactMapValues(\.rectangularRenderModel)
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
