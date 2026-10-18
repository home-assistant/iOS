#if !os(watchOS)
import SFSafeSymbols
import SwiftUI
import WidgetKit

/// Lock screen inline layout: a single line combining the configured series, e.g. "↑12,4 ↓6,2 kWh".
/// The system renders one leading symbol next to the text, so the per-series icons collapse into
/// direction arrows carried by the text itself.
@available(iOS 17, *)
public struct WidgetEnergyAccessoryInlineContentView: View {
    private let stats: [WidgetEnergyStatModel]
    /// What to say when there is nothing to report. Callers own the empty state, which is what
    /// distinguishes unconfigured from configured-but-no-data.
    private let emptyText: String

    public init(stats: [WidgetEnergyStatModel], emptyText: String) {
        self.stats = stats
        self.emptyText = emptyText
    }

    public var body: some View {
        Label {
            Text(verbatim: stats.isEmpty ? emptyText : Self.text(for: stats))
        } icon: {
            Image(systemSymbol: stats.first?.accessorySymbol ?? .boltFill)
        }
        .widgetBackground(Color.clear)
    }

    /// Joins the metrics onto one line. The unit is hoisted to the end when every series shares it,
    /// which is the common case (both in kWh, or both in live watts) and buys back scarce width.
    /// Empty in, empty out — callers own the empty state.
    public static func text(for stats: [WidgetEnergyStatModel]) -> String {
        guard !stats.isEmpty else { return "" }
        let units = stats.compactMap(\.unit)
        if units.count == stats.count, Set(units).count == 1, let unit = units.first {
            let values = stats.map { $0.direction.arrowCharacter + $0.value }.joined(separator: " ")
            return "\(values) \(unit)"
        }
        return stats.map { $0.direction.arrowCharacter + $0.valueWithUnit }.joined(separator: " ")
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyAccessoryInlineContentView(
        stats: WidgetEnergySampleData.stats,
        emptyText: "No energy data"
    )
    .padding()
}
#endif
