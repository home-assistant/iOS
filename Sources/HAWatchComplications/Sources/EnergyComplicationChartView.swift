import Charts
import SwiftUI
import WidgetKit

/// The complication's energy chart: the Energy widget's graph, stripped to what survives at
/// complication size.
///
/// Same bars, same stack order, same colours as `WidgetEnergyChartView` on iOS — each bucket draws
/// what the home consumed above the axis, solar at the bottom, then the battery's discharge, then
/// the grid, with what left the property hanging below: battery charge nearest the axis, energy
/// returned to the grid beyond it.
///
/// What it drops is the chrome. A rectangular complication is around forty points tall once the
/// figures above it have had their line, which is not enough for axis labels, grid lines or a
/// legend — so the zero rule is the only reference left, and it is the one that matters, because it
/// is what tells the two directions apart.
@available(iOS 16.0, watchOS 10.0, *)
public struct EnergyComplicationChartView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    private let bars: [EnergyComplicationChartBar]

    public init(bars: [EnergyComplicationChartBar]) {
        self.bars = bars
    }

    /// One bar of a bucket, given an explicit span rather than left to the chart's own stacking —
    /// the same reasoning as the widget's chart: stacking butts rounded segments against each other
    /// and can't hang a bar below zero. Every segment has one end on the axis, which is what lets
    /// ``baselineHalf`` square off the end that meets it.
    private struct Segment: Identifiable {
        let date: Date
        let start: Double
        let end: Double
        let series: EnergyComplicationSeries
        var id: String { "\(series.rawValue)-\(date.timeIntervalSince1970)" }

        var baselineHalf: Double { (start + end) / 2 }
    }

    /// What the home consumed, innermost layer first: its own solar, then the battery's discharge,
    /// then the grid — read from the axis up, the way the dashboard stacks it.
    private static var positiveLayers: [Layer] {
        [
            Layer(series: .solar) { $0.solarUsed },
            Layer(series: .batteryOut) { $0.batteryUsed },
            Layer(series: .grid) { $0.gridUsed },
        ]
    }

    /// What left the property, innermost first: charge going into the battery sits against the axis,
    /// energy returned to the grid hangs below it.
    private static var negativeLayers: [Layer] {
        [
            Layer(series: .batteryIn) { $0.batteryCharged },
            Layer(series: .gridReturn) { $0.gridReturned },
        ]
    }

    /// One layer of the bar, from the axis outwards.
    private struct Layer {
        let series: EnergyComplicationSeries
        let value: (EnergyComplicationChartBar) -> Double
    }

    private enum Layout {
        static let cornerRadius: CGFloat = 1
        static let baselineWidth: CGFloat = 0.5
        static let baselineOpacity: CGFloat = 0.35
    }

    public var body: some View {
        // Order matters: later marks paint over earlier ones, which is what stacks each side of the
        // axis without notching the rounded caps.
        let segments = Self.segments(in: bars, layers: Self.positiveLayers, sign: 1)
            + Self.segments(in: bars, layers: Self.negativeLayers, sign: -1)
        Chart {
            RuleMark(y: .value("Energy", 0))
                .lineStyle(StrokeStyle(lineWidth: Layout.baselineWidth))
                .foregroundStyle(Color.primary.opacity(Layout.baselineOpacity))

            ForEach(segments) { segment in
                BarMark(
                    x: .value("Time", segment.date, unit: .hour),
                    yStart: .value("Energy", segment.start),
                    yEnd: .value("Energy", segment.end)
                )
                .foregroundStyle(color(for: segment.series))
                .cornerRadius(Layout.cornerRadius)

                // `cornerRadius` rounds all four corners, which lifts the bars off the axis they grow
                // out of. Redrawing the half that meets the baseline with the rounding off leaves
                // only the outer end rounded.
                BarMark(
                    x: .value("Time", segment.date, unit: .hour),
                    yStart: .value("Energy", 0),
                    yEnd: .value("Energy", segment.baselineHalf)
                )
                .foregroundStyle(color(for: segment.series))
                .cornerRadius(0)
            }
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// A face that tints its complications flattens saturated colours to luminance, where solar
    /// orange and grid blue come out as two indistinguishable greys. Outside full colour the stack
    /// is drawn in shades of the accent instead, keeping the layers apart by weight in the one
    /// dimension the system leaves alone.
    private func color(for series: EnergyComplicationSeries) -> Color {
        guard renderingMode != .fullColor else { return series.color }
        return .primary.opacity(Self.tintedOpacity(for: series))
    }

    /// Weights for the tinted rendering, ordered the way the stack is: heaviest against the axis on
    /// the consumption side, lightest at the far end of what was exported.
    private static func tintedOpacity(for series: EnergyComplicationSeries) -> CGFloat {
        switch series {
        case .solar: 1.0
        case .batteryOut: 0.75
        case .grid: 0.55
        case .batteryIn: 0.45
        case .gridReturn: 0.3
        case .gas: 0.55
        }
    }

    /// Turns a stack of layers into whole spans, outermost first, so each shorter layer covers the
    /// lower part of the one behind it and every boundary keeps a single rounded cap. Empty spans
    /// are dropped: a zero-height bar still draws its corner radius as a sliver on the axis.
    private static func segments(
        in bars: [EnergyComplicationChartBar],
        layers: [Layer],
        sign: Double
    ) -> [Segment] {
        bars.flatMap { bar -> [Segment] in
            var cumulative = 0.0
            let tops = layers.map { layer -> Double in
                cumulative += max(layer.value(bar), 0)
                return cumulative
            }
            return Array(zip(layers, tops)).reversed().compactMap { layer, top in
                guard top > 0 else { return nil }
                return Segment(
                    date: bar.date,
                    start: min(0, sign * top),
                    end: max(0, sign * top),
                    series: layer.series
                )
            }
        }
    }
}

#if DEBUG
@available(iOS 16.0, watchOS 10.0, *)
#Preview {
    EnergyComplicationChartView(bars: EnergyComplicationSampleData.bars)
        .frame(width: 160, height: 40)
        .padding()
        .background(.black)
        .environment(\.colorScheme, .dark)
}
#endif
