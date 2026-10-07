#if !os(watchOS)
import Charts
import Foundation
import SwiftUI

/// Energy bar chart mirroring the Home Assistant frontend energy graph. Each bucket draws one bar
/// for everything the home consumed, stacked in the dashboard's own order — solar (orange) at the
/// bottom, then the battery's discharge (teal), then the grid (blue) — so a bar the sun covered
/// entirely reads as solid orange. Below the axis hang the flows that left the home: battery
/// charging (pink) nearest the axis, energy returned to the grid (purple) beyond it. Buckets are
/// hourly for single-day periods and daily for week/month; the y-axis (kWh) sits on the trailing
/// edge.
///
/// Gas is deliberately absent. It is metered in m³ as often as in kWh, so the dashboard gives it a
/// card of its own rather than a series on this one; the widget shows it as a figure instead.
@available(iOS 17, *)
public struct WidgetEnergyChartView: View {
    private let points: [WidgetEnergyChartPoint]
    private let showsGrid: Bool
    private let showsSolar: Bool
    private let showsBattery: Bool
    /// Daily buckets (week/month) render one bar per day; single-day periods render hourly bars.
    private let isDaily: Bool
    /// How many days apart the x-axis labels sit, once the buckets are daily.
    private let dayStride: Int
    /// The window the chart covers, end exclusive. Anchors the x-axis when the data stops short of
    /// the period — or when there is no data at all and there is nothing but the axes to draw.
    private let periodRange: (start: Date, end: Date)

    public init(
        points: [WidgetEnergyChartPoint],
        showsGrid: Bool = true,
        showsSolar: Bool = true,
        showsBattery: Bool = false,
        isDaily: Bool = false,
        dayStride: Int = 1,
        periodRange: (start: Date, end: Date)
    ) {
        self.points = points
        self.showsGrid = showsGrid
        self.showsSolar = showsSolar
        self.showsBattery = showsBattery
        self.isDaily = isDaily
        self.dayStride = dayStride
        self.periodRange = periodRange
    }

    private static let gridFlow = "grid"
    private static let solarFlow = "solar"
    private static let returnedFlow = "returned"
    private static let batteryOutFlow = "batteryOut"
    private static let batteryInFlow = "batteryIn"

    /// One bar of a bucket, given an explicit span rather than left to the chart's own stacking.
    /// Stacking would butt the two consumption series end to end — two rounded segments pushing
    /// each other up the axis — and it can't hang the returned-energy bar below zero either.
    /// Every segment starts or ends on the zero axis, which is what lets ``baselineHalf`` square
    /// off the end that meets it.
    private struct FlowSegment: Identifiable {
        let date: Date
        let start: Double
        let end: Double
        let flow: String
        var id: String { "\(flow)-\(date.timeIntervalSince1970)" }

        /// Midpoint of the bar. Every segment has one end on the zero axis, so the half between
        /// here and zero is the half that meets the baseline — redrawn square to undo the rounding
        /// there. Half rather than a fixed depth because the chart has no pixel-to-value scale to
        /// convert a corner radius with, and half of any bar is always at least as deep as one.
        var baselineHalf: Double { (start + end) / 2 }
    }

    /// One layer of the bar, from the axis outwards.
    private struct Layer {
        let flow: String
        let value: (WidgetEnergyChartPoint) -> Double
    }

    /// What the home consumed, innermost layer first: its own solar, then the battery's discharge,
    /// then the grid — the dashboard's stack order, read from the axis up.
    ///
    /// Every layer is a used share rather than a raw meter reading. A bucket that imported and
    /// exported at once, or charged the battery while drawing, only demanded the difference, and the
    /// dashboard's graph plots that difference — plotting the raw import would stand the bar above
    /// what the home ever used.
    ///
    /// The exception is a chart showing generation on its own: with neither grid nor battery on
    /// screen there is no bar to be a share of, and nothing visible for the exported part to have
    /// gone to, so solar simply plots its full output.
    private var positiveLayers: [Layer] {
        let solarIsAlone = !showsGrid && !showsBattery
        return [
            showsSolar ? Layer(flow: Self.solarFlow) { solarIsAlone ? $0.solar : $0.solarUsed } : nil,
            showsBattery ? Layer(flow: Self.batteryOutFlow) { $0.batteryUsed } : nil,
            showsGrid ? Layer(flow: Self.gridFlow) { $0.gridUsed } : nil,
        ].compactMap { $0 }
    }

    /// What left the home, innermost layer first: charge going into the battery sits against the
    /// axis, energy returned to the grid hangs below it. Each belongs to its own series, so it
    /// disappears along with it.
    private var negativeLayers: [Layer] {
        [
            showsBattery ? Layer(flow: Self.batteryInFlow) { $0.batteryCharged } : nil,
            showsGrid ? Layer(flow: Self.returnedFlow) { $0.gridReturned } : nil,
        ].compactMap { $0 }
    }

    /// Turns a stack of layers into bars, each one spanning the axis to the top of its own layer.
    ///
    /// Whole spans rather than abutting ones, and ordered outermost first, because the bars carry a
    /// corner radius: a stack of abutting segments would round every internal boundary into a pair
    /// of facing notches. Painting the tallest first and letting each shorter layer cover the lower
    /// part of it leaves one rounded cap per boundary, which is the dashboard's look. It also keeps
    /// every segment with one end on the zero axis, which is what lets ``FlowSegment/baselineHalf``
    /// square off the end that meets it.
    ///
    /// Empty spans are dropped: a zero-height bar would still draw its corner radius as a sliver
    /// sitting on the axis.
    private func segments(stacking layers: [Layer], sign: Double) -> [FlowSegment] {
        points.flatMap { point -> [FlowSegment] in
            var cumulative = 0.0
            let tops = layers.map { layer -> Double in
                cumulative += max(layer.value(point), 0)
                return cumulative
            }
            return Array(zip(layers, tops)).reversed().compactMap { layer, top in
                guard top > 0 else { return nil }
                return FlowSegment(
                    date: point.date,
                    start: min(0, sign * top),
                    end: max(0, sign * top),
                    flow: layer.flow
                )
            }
        }
    }

    /// Force the x-axis to represent the whole period even when data only reaches "now" — or, with no
    /// data at all, when there is nothing but the axes to draw.
    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let start: Date
        let end: Date
        if let first = points.first?.date, let last = points.last?.date {
            start = calendar.startOfDay(for: first)
            end = calendar.startOfDay(for: last).addingTimeInterval(24 * 3600)
        } else {
            // `end` is exclusive, so step back inside it before rounding up to the end of its day.
            start = calendar.startOfDay(for: periodRange.start)
            end = calendar.startOfDay(for: periodRange.end.addingTimeInterval(-1)).addingTimeInterval(24 * 3600)
        }
        return start ... max(end, start.addingTimeInterval(24 * 3600))
    }

    public var body: some View {
        // Resolved once: the empty check and the bars would otherwise rebuild them twice. Order
        // matters — later marks paint over earlier ones, which is what stacks each side of the axis.
        let used = segments(stacking: positiveLayers, sign: 1)
        let exported = segments(stacking: negativeLayers, sign: -1)
        Chart {
            ForEach(used + exported) { segment in
                BarMark(
                    x: .value("Time", segment.date, unit: isDaily ? .day : .hour),
                    yStart: .value("Energy", segment.start),
                    yEnd: .value("Energy", segment.end)
                )
                .foregroundStyle(by: .value("Flow", segment.flow))
                .cornerRadius(2)

                // `cornerRadius` rounds all four corners, which lifts the bars off the axis they
                // grow out of. Redrawing the baseline half on top of that, with the rounding
                // explicitly off, leaves only the outer end rounded. The zero is not redundant:
                // bars carry a corner radius of their own without it.
                BarMark(
                    x: .value("Time", segment.date, unit: isDaily ? .day : .hour),
                    yStart: .value("Energy", 0),
                    yEnd: .value("Energy", segment.baselineHalf)
                )
                .foregroundStyle(by: .value("Flow", segment.flow))
                .cornerRadius(0)
            }

            if used.isEmpty, exported.isEmpty {
                // Nothing to plot: an invisible bar still gives the y-axis a domain, so the empty
                // chart draws both axes instead of a bare grid.
                BarMark(
                    x: .value("Time", xDomain.lowerBound, unit: isDaily ? .day : .hour),
                    y: .value("Energy", 1)
                )
                .opacity(0)
            }
        }
        .chartForegroundStyleScale([
            Self.solarFlow: WidgetEnergyPalette.solar,
            Self.gridFlow: WidgetEnergyPalette.consumption,
            Self.returnedFlow: WidgetEnergyPalette.gridReturn,
            Self.batteryOutFlow: WidgetEnergyPalette.batteryOut,
            Self.batteryInFlow: WidgetEnergyPalette.batteryIn,
        ])
        .chartLegend(.hidden)
        .chartXScale(domain: xDomain)
        .chartXAxis {
            if isDaily {
                AxisMarks(values: .stride(by: .day, count: dayStride)) { _ in
                    AxisGridLine().foregroundStyle(WidgetEnergyPalette.secondaryText.opacity(0.12))
                    AxisValueLabel(format: .dateTime.day())
                        .font(.system(size: 9))
                        .foregroundStyle(WidgetEnergyPalette.secondaryText)
                }
            } else {
                AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                    AxisGridLine().foregroundStyle(WidgetEnergyPalette.secondaryText.opacity(0.12))
                    AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                        .font(.system(size: 9))
                        .foregroundStyle(WidgetEnergyPalette.secondaryText)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine().foregroundStyle(WidgetEnergyPalette.secondaryText.opacity(0.12))
                AxisValueLabel()
                    .font(.system(size: 9))
                    .foregroundStyle(WidgetEnergyPalette.secondaryText)
            }
        }
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyChartView(
        points: WidgetEnergySampleData.chartPoints,
        periodRange: WidgetEnergySampleData.dayRange
    )
    .padding()
    .frame(height: 150)
    .background(WidgetEnergyPalette.background)
}
#endif
