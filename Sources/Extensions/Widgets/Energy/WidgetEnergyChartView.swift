import Charts
import SwiftUI

/// Energy bar chart mirroring the Home Assistant frontend energy graph: grid consumption (blue)
/// and solar generation (orange) stack as positive bars above the zero axis. Buckets are hourly for
/// single-day periods and daily for week/month; the y-axis (kWh) sits on the trailing edge.
@available(iOS 17, *)
struct WidgetEnergyChartView: View {
    let points: [WidgetEnergyEntry.ChartPoint]
    var source: WidgetEnergySource = .auto
    var period: WidgetEnergyPeriod = .today
    /// Anchors the x-axis to the right days when there are no points to derive it from.
    var date = Date()

    private static let gridFlow = "grid"
    private static let solarFlow = "solar"

    private struct FlowPoint: Identifiable {
        let date: Date
        let value: Double
        let flow: String
        var id: String { "\(flow)-\(date.timeIntervalSince1970)" }
    }

    /// One entry per (bucket, series). Both are positive so the bars stack upward above the axis
    /// (grid on the bottom, solar on top), matching the Home Assistant energy graph.
    private var flowPoints: [FlowPoint] {
        points.flatMap { point -> [FlowPoint] in
            var entries: [FlowPoint] = []
            if source.showsGrid {
                entries.append(FlowPoint(date: point.date, value: point.grid, flow: Self.gridFlow))
            }
            if source.showsSolar {
                entries.append(FlowPoint(date: point.date, value: point.solar, flow: Self.solarFlow))
            }
            return entries
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
        Chart {
            ForEach(flowPoints) { point in
                BarMark(
                    x: .value("Time", point.date, unit: isDaily ? .day : .hour),
                    y: .value("Energy", point.value)
                )
                .foregroundStyle(by: .value("Flow", point.flow))
                .cornerRadius(2)
            }

            if flowPoints.isEmpty {
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
            Self.gridFlow: WidgetEnergyStyle.consumption,
            Self.solarFlow: WidgetEnergyStyle.solar,
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
    let dayStart = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
    let points = (0 ..< 24).map { hour -> WidgetEnergyEntry.ChartPoint in
        let h = Double(hour)
        let grid = 0.25 + 0.8 * exp(-pow(h - 7, 2) / 4) + 1.0 * exp(-pow(h - 20, 2) / 6)
        let solar = h >= 6 && h <= 18 ? 1.6 * sin((h - 6) / 12 * .pi) : 0
        return WidgetEnergyEntry.ChartPoint(
            date: dayStart.addingTimeInterval(h * 3600),
            grid: grid,
            solar: solar
        )
    }
    return WidgetEnergyChartView(points: points)
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
