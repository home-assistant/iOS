import SwiftUI
import WidgetKit

/// The energy complication's on-face content: the period's figures on one line, the period's chart
/// filling everything below them.
///
/// This is the rectangular family's layout, and it is the shape the Energy widget's card already
/// has on the phone — headline numbers, graph underneath, one colour per series throughout. A
/// complication is roughly a fifth of that card's area, so what changes is what had to go: the
/// period caption, the axis labels and the legend, none of which survive at this size, and none of
/// which carry a number.
///
/// Single source of truth for every surface that draws this complication, the way
/// ``RectangularComplicationContentView`` is for the entity one: the widget extension only builds an
/// ``EnergyComplicationRenderModel``.
@available(iOS 16.0, watchOS 10.0, *)
public struct EnergyComplicationContentView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    private enum Layout {
        static let rowSpacing: CGFloat = 1
        static let statSpacing: CGFloat = 6
        static let statItemSpacing: CGFloat = 2
        static let serverNameSize: CGFloat = 9
        static let messageSize: CGFloat = 12
        static let minimumScaleFactor: CGFloat = 0.6
        /// Past this many figures the units go and the rest shrinks. Three or four value/unit pairs
        /// on one complication-wide line leaves nothing legible, and every unit but a gas meter's is
        /// kWh anyway — where the figure itself is never redundant.
        static let unitsFitUpToStatCount = 2
    }

    /// How much room a figure has, which is decided by how many of them there are.
    private enum StatSize {
        case regular
        case condensed

        var symbol: CGFloat { self == .regular ? 10 : 8 }
        var value: CGFloat { self == .regular ? 14 : 11 }
        var unit: CGFloat { self == .regular ? 9 : 8 }
    }

    public let model: EnergyComplicationRenderModel

    public init(model: EnergyComplicationRenderModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            if let serverName = model.serverName, !serverName.isEmpty {
                Text(serverName)
                    .font(.system(size: Layout.serverNameSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(Layout.minimumScaleFactor)
            }
            // Nothing to plot means no chart rather than a bare axis. A dashboard with gas and
            // nothing else has no series on this chart at all — gas is a figure, never a bar — so
            // the axis would sit there empty for good, saying nothing the figure above it doesn't.
            if let message = model.message, !message.isEmpty {
                // No figures and no chart: the whole complication is the reason there aren't any.
                Text(message)
                    .font(.system(size: Layout.messageSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(Layout.minimumScaleFactor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                statsRow
                if !model.bars.isEmpty {
                    EnergyComplicationChartView(bars: model.bars)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var statsRow: some View {
        let size: StatSize = model.stats.count > Layout.unitsFitUpToStatCount ? .condensed : .regular
        return HStack(spacing: Layout.statSpacing) {
            ForEach(model.stats) { stat in
                statView(stat, size: size)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(Layout.minimumScaleFactor)
    }

    private func statView(_ stat: EnergyComplicationStat, size: StatSize) -> some View {
        HStack(spacing: Layout.statItemSpacing) {
            stat.series.symbolImage
                .resizable()
                .scaledToFit()
                .frame(width: size.symbol, height: size.symbol)
            Text(stat.value)
                .font(.system(size: size.value, weight: .semibold, design: .rounded))
            if let unit = stat.unit, size == .regular {
                Text(unit)
                    .font(.system(size: size.unit))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(color(for: stat.series))
    }

    /// A tinting face flattens saturated colours to luminance, where the series colours come out as
    /// indistinguishable greys — so outside full colour the figures are drawn in the face's own
    /// accent instead of a colour it was going to discard anyway.
    private func color(for series: EnergyComplicationSeries) -> Color {
        renderingMode == .fullColor ? series.color : .primary
    }
}

#if DEBUG
/// Renders on a dark rounded "watch face" so the default `.primary` text is legible, matching the
/// watch's black face.
@available(iOS 16.0, watchOS 10.0, *)
private func face(_ model: EnergyComplicationRenderModel) -> some View {
    EnergyComplicationContentView(model: model)
        .padding(8)
        .frame(width: 170, height: 76)
        .background(.black, in: .rect(cornerRadius: 14))
        .environment(\.colorScheme, .dark)
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Grid and solar") {
    face(.init(stats: EnergyComplicationSampleData.stats, bars: EnergyComplicationSampleData.bars))
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Every source") {
    face(.init(
        stats: EnergyComplicationSampleData.allSourceStats,
        bars: EnergyComplicationSampleData.batteryBars,
        serverName: "Home"
    ))
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Nothing to show") {
    face(.init(serverName: "Holiday home", message: "No energy dashboard"))
}
#endif
