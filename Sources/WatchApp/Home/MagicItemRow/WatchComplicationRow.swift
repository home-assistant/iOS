import HAWatchComplications
import SFSafeSymbols
import Shared
import SwiftUI

/// A rectangular complication rendered inline in the watch's item list.
///
/// The row is not a button: a complication is something to read, not to run. It draws through the
/// shared `RectangularComplicationContentView`, so what the list shows is the same layout the watch
/// face shows, and it refreshes on the same visible-only five-second cadence as the entity rows.
struct WatchComplicationRow: View {
    @StateObject private var viewModel: WatchComplicationRowViewModel
    /// When set, the row renders this model and never polls. Previews and snapshot tests only —
    /// there is no server behind them (mirrors `WatchHomeView`'s `autoLoad`).
    private let previewRenderModel: RectangularComplicationRenderModel?

    init(
        item: MagicItem,
        itemInfo: MagicItem.Info,
        previewRenderModel: RectangularComplicationRenderModel? = nil
    ) {
        self._viewModel = .init(wrappedValue: .init(item: item, itemInfo: itemInfo))
        self.previewRenderModel = previewRenderModel
    }

    var body: some View {
        let model = previewRenderModel ?? viewModel.renderModel
        // The `#available` check stands alone rather than being combined with the `let model` binding:
        // SwiftUI only narrows the branch's availability (`buildLimitedAvailability`) when the
        // condition is nothing but `#available`.
        VStack(alignment: .leading, spacing: 0) {
            if #available(watchOS 10.0, *) {
                if let model {
                    RectangularComplicationContentView(model: model)
                } else {
                    nameOnlyLabel
                }
            } else {
                nameOnlyLabel
            }
        }
        .padding(DesignSystem.Spaces.one)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            // Same warning the entity rows use: the values shown may no longer be current.
            if viewModel.isStale {
                Image(systemSymbol: .exclamationmarkCircleFill)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, .orange)
                    .font(.system(size: 12))
                    .padding(DesignSystem.Spaces.half)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: viewModel.fallbackName))
        .watchHomeItemRowStyle(tint: nil)
        .onAppear {
            guard previewRenderModel == nil else { return }
            // watchOS 9 renders the name and nothing else, so polling there would spend network and
            // battery on values the row can never show — and raise a stale badge over them.
            guard #available(watchOS 10.0, *) else { return }
            viewModel.startUpdates()
        }
        .onDisappear {
            viewModel.stopUpdates()
        }
    }

    /// Stand-in for the complication's layout: shown on watchOS 9, which has no accessory-family
    /// rendering, and while a freshly-added complication has not been fetched on this watch yet. The
    /// row says what it is rather than collapsing to an empty strip.
    private var nameOnlyLabel: some View {
        Text(verbatim: viewModel.fallbackName)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

#Preview("Gauge") {
    List {
        WatchComplicationRow(
            item: .init(id: "complication-1", serverId: "1", type: .complication),
            itemInfo: .init(id: "1-complication-1", name: "Battery", iconName: "battery"),
            previewRenderModel: .init(
                showsIcon: false,
                title: "Battery",
                showsName: true,
                fraction: 0.68,
                minLabel: "0",
                maxLabel: "100",
                valueText: "68 %",
                showsValue: true,
                tint: .green
            )
        )
    }
}

#Preview("Value as text") {
    List {
        WatchComplicationRow(
            item: .init(id: "complication-2", serverId: "1", type: .complication),
            itemInfo: .init(id: "1-complication-2", name: "Front door", iconName: "door"),
            previewRenderModel: .init(
                showsIcon: false,
                title: "Front door",
                showsName: true,
                subtitle: "Lock",
                showsSubtitle: true,
                valueText: "Locked",
                showsValue: true
            )
        )
    }
}
