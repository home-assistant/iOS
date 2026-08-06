import Charts
import SwiftUI

/// Hourly energy bar chart mirroring the Home Assistant frontend energy graph: grid consumption
/// (blue) and solar generation (orange) stack as positive bars above the zero axis. The
/// x-axis spans the full day; the y-axis (kWh) sits on the trailing edge.
@available(iOS 17, *)
struct WidgetEnergyChartView: View {
    let points: [WidgetEnergyEntry.ChartPoint]
    var source: WidgetEnergySource = .auto

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

    /// Force the x-axis to represent the whole day even when the period only has data up to "now".
    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        guard let first = points.first?.date, let last = points.last?.date else {
            let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
            return start ... start.addingTimeInterval(24 * 3600)
        }
        let start = calendar.startOfDay(for: first)
        let end = calendar.startOfDay(for: last).addingTimeInterval(24 * 3600)
        return start ... end
    }

    var body: some View {
        Chart {
            ForEach(flowPoints) { point in
                BarMark(
                    x: .value("Time", point.date, unit: .hour),
                    y: .value("Energy", point.value)
                )
                .foregroundStyle(by: .value("Flow", point.flow))
                .cornerRadius(2)
            }
        }
        .chartForegroundStyleScale([
            Self.gridFlow: WidgetEnergyStyle.consumption,
            Self.solarFlow: WidgetEnergyStyle.solar,
        ])
        .chartLegend(.hidden)
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine().foregroundStyle(WidgetEnergyStyle.secondaryText.opacity(0.12))
                AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                    .font(.system(size: 9))
                    .foregroundStyle(WidgetEnergyStyle.secondaryText)
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
