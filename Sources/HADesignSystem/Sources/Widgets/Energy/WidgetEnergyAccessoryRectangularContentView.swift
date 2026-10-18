#if !os(watchOS)
import HAIconic
import SwiftUI
import WidgetKit

/// Lock screen rectangular layout: the period title, then one row per configured energy series.
@available(iOS 17, *)
public struct WidgetEnergyAccessoryRectangularContentView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    private let stats: [WidgetEnergyStatModel]
    private let periodTitle: String
    /// What to say when there is nothing to report — which is where "not configured" and "no data"
    /// are told apart, so the widget decides the wording.
    private let emptyText: String

    public init(stats: [WidgetEnergyStatModel], periodTitle: String, emptyText: String) {
        self.stats = stats
        self.periodTitle = periodTitle
        self.emptyText = emptyText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if stats.isEmpty {
                // No period header here: there is no figure for it to caption.
                Text(verbatim: emptyText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            } else if stats.count > 2 {
                // Past two figures there is no room for both the caption and the rows: the
                // accessory is barely three lines tall. The period is the thing to drop — it
                // repeats what the widget's configuration already says, where a figure doesn't.
                columns
            } else {
                Text(verbatim: periodTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ForEach(stats) { stat in
                    row(for: stat, size: .regular)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackground(Color.clear)
    }

    /// Three or four figures in two columns, which is what the accessory's width can carry when its
    /// height can't take another row.
    private var columns: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: DesignSystem.Spaces.half, alignment: .leading),
                count: 2
            ),
            alignment: .leading,
            spacing: 1
        ) {
            ForEach(stats) { stat in
                row(for: stat, size: .condensed)
            }
        }
    }

    /// How much room a row of the accessory has. Not the shared ``WidgetEnergyStatDensity``: these
    /// rows carry no caption, so they scale on their own terms.
    private enum RowSize {
        case regular
        case condensed

        var icon: CGFloat { self == .regular ? 12 : 10 }
        var value: CGFloat { self == .regular ? 15 : 12 }
        var unit: CGFloat { self == .regular ? 10 : 8 }
    }

    private func row(for stat: WidgetEnergyStatModel, size: RowSize) -> some View {
        HStack(spacing: DesignSystem.Spaces.half) {
            Text(verbatim: stat.icon.unicode)
                .font(.custom(MaterialDesignIcons.familyName, size: size.icon))
            Text(verbatim: stat.value)
                .font(.system(size: size.value, weight: .semibold, design: .rounded))
            if let unit = stat.unit {
                Text(verbatim: unit)
                    .font(.system(size: size.unit))
                    .foregroundStyle(.secondary)
                    // Gives way before the figure does, for the same reason it does on a card.
                    .minimumScaleFactor(0.4)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(WidgetEnergyPalette.accessoryColor(stat.color, mode: renderingMode))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

@available(iOS 17, *)
#Preview("Two sources") {
    WidgetEnergyAccessoryRectangularContentView(
        stats: WidgetEnergySampleData.stats,
        periodTitle: "Today",
        emptyText: "No energy data"
    )
    .frame(width: 160, height: 72)
}

@available(iOS 17, *)
#Preview("Four sources") {
    WidgetEnergyAccessoryRectangularContentView(
        stats: WidgetEnergySampleData.allSourceStats,
        periodTitle: "Today",
        emptyText: "No energy data"
    )
    .frame(width: 160, height: 72)
}
#endif
