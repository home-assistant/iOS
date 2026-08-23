import Charts
import SwiftUI

/// Energy bar chart mirroring the Home Assistant frontend energy graph. Each bucket draws one bar
/// for everything the home consumed (blue), with the share its own solar covered painted over the
/// bottom of it (orange) — so a bar the sun covered entirely reads as solid orange. Energy returned
/// to the grid (purple) hangs below the axis. Buckets are hourly for single-day periods and daily
/// for week/month; the y-axis (kWh) sits on the trailing edge.
@available(iOS 17, *)
struct WidgetEnergyChartView: View {
    let points: [WidgetEnergyEntry.ChartPoint]
    var source: WidgetEnergySource = .auto
    var period: WidgetEnergyPeriod = .today
    /// Anchors the x-axis to the right days when there are no points to derive it from.
    var date = Date()

    private static let gridFlow = "grid"
    private static let solarFlow = "solar"
    private static let returnedFlow = "returned"

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

    /// The full height of each bucket's bar: everything the home consumed, drawn from the grid and
    /// from its own solar. Painted first and in one piece, so the solar share can overlay its lower
    /// part instead of being stacked on top of it.
    ///
    /// Both halves are the used shares rather than the raw meter readings. A bucket that imported
    /// and exported at once only demanded the difference, and the dashboard's graph plots that
    /// difference — plotting the raw import would stand the bar above what the home ever used.
    private var consumptionSegments: [FlowSegment] {
        guard source.showsGrid else { return [] }
        return segments(flow: Self.gridFlow) { point in
            (0, point.gridUsed + (source.showsSolar ? point.solarUsed : 0))
        }
    }

    /// The solar share of what the home used, overlaying the bar above. When generation covered
    /// everything the home consumed, it covers the bar completely and no blue is left showing.
    ///
    /// With the grid hidden there is no consumption bar to overlay and no exported share on screen
    /// to take off it, so the bars simply show the full generation.
    private var solarSegments: [FlowSegment] {
        guard source.showsSolar else { return [] }
        return segments(flow: Self.solarFlow) { point in
            (0, source.showsGrid ? point.solarUsed : point.solar)
        }
    }

    /// Energy sent back to the grid, hanging below the axis. It belongs to the grid series, so it
    /// disappears along with it.
    private var returnedSegments: [FlowSegment] {
        guard source.showsGrid else { return [] }
        return segments(flow: Self.returnedFlow) { point in (-point.gridReturned, 0) }
    }

    /// Turns one span per bucket into bars, dropping the empty ones: a zero-height bar would still
    /// draw its corner radius as a sliver sitting on the axis.
    private func segments(
        flow: String,
        span: (WidgetEnergyEntry.ChartPoint) -> (start: Double, end: Double)
    ) -> [FlowSegment] {
        points.compactMap { point in
            let span = span(point)
            guard span.start != span.end else { return nil }
            return FlowSegment(date: point.date, start: span.start, end: span.end, flow: flow)
        }
    }

    /// Daily buckets (week/month) render one bar per day; single-day periods render hourly bars.
    private var isDaily: Bool {
        switch period {
        case .today, .yesterday: false
        case .thisWeek, .thisMonth: true
        }
    }

    private var dayStride: Int {
        switch period {
        case .thisMonth: 7
        default: 1
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
            let range = period.dateRange(now: date)
            start = calendar.startOfDay(for: range.start)
            end = calendar.startOfDay(for: range.end.addingTimeInterval(-1)).addingTimeInterval(24 * 3600)
        }
        return start ... max(end, start.addingTimeInterval(24 * 3600))
    }

    var body: some View {
        // Resolved once: the empty check and the bars would otherwise rebuild them twice. Order
        // matters — later marks paint over earlier ones, which is what puts solar over consumption.
        let consumption = consumptionSegments
        let solar = solarSegments
        let returned = returnedSegments
        Chart {
            ForEach(consumption + solar + returned) { segment in
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

            if consumption.isEmpty, solar.isEmpty, returned.isEmpty {
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
            Self.solarFlow: WidgetEnergyStyle.solar,
            Self.gridFlow: WidgetEnergyStyle.consumption,
            Self.returnedFlow: WidgetEnergyStyle.gridReturn,
        ])
        .chartLegend(.hidden)
        .chartXScale(domain: xDomain)
        .chartXAxis {
            if isDaily {
                AxisMarks(values: .stride(by: .day, count: dayStride)) { _ in
                    AxisGridLine().foregroundStyle(WidgetEnergyStyle.secondaryText.opacity(0.12))
                    AxisValueLabel(format: .dateTime.day())
                        .font(.system(size: 9))
                        .foregroundStyle(WidgetEnergyStyle.secondaryText)
                }
            } else {
                AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                    AxisGridLine().foregroundStyle(WidgetEnergyStyle.secondaryText.opacity(0.12))
                    AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                        .font(.system(size: 9))
                        .foregroundStyle(WidgetEnergyStyle.secondaryText)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine().foregroundStyle(WidgetEnergyStyle.secondaryText.opacity(0.12))
                AxisValueLabel()
                    .font(.system(size: 9))
                    .foregroundStyle(WidgetEnergyStyle.secondaryText)
            }
        }
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyChartView(
        points: WidgetEnergyChartSample.day(
            startingAt: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        )
    )
    .padding()
    .frame(height: 150)
    .background(WidgetEnergyStyle.background)
}

@available(iOS 17, *)
#Preview("Solar only") {
    WidgetEnergyChartView(
        points: WidgetEnergyChartSample.day(
            startingAt: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        ),
        source: .solar
    )
    .padding()
    .frame(height: 150)
    .background(WidgetEnergyStyle.background)
}

@available(iOS 17, *)
#Preview("No data") {
    WidgetEnergyChartView(points: [], period: .today)
        .padding()
        .frame(height: 150)
        .background(WidgetEnergyStyle.background)
}
