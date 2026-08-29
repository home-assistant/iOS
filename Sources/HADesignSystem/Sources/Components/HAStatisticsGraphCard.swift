#if !os(watchOS)
import SwiftUI

/// A statistics chart on a card. The SwiftUI counterpart of the frontend's
/// `hui-statistics-graph-card`.
public struct HAStatisticsGraphCard: View {
    private let title: String?
    private let bars: [HAStatisticsBar]
    private let colors: [String: Color]
    private let timeZone: TimeZone

    public init(
        title: String? = nil,
        bars: [HAStatisticsBar],
        colors: [String: Color] = [:],
        timeZone: TimeZone = .current
    ) {
        self.title = title
        self.bars = bars
        self.colors = colors
        self.timeZone = timeZone
    }

    public var body: some View {
        HACard(header: title) {
            HAStatisticsChart(bars: bars, colors: colors, timeZone: timeZone)
                .padding(DesignSystem.Spaces.two)
        }
    }
}

private let sampleStart = Date(timeIntervalSince1970: 1_787_961_600)

private let sampleBars: [HAStatisticsBar] = (0 ..< 5).map { day in
    HAStatisticsBar(
        date: sampleStart.addingTimeInterval(Double(day) * 86400),
        contributions: [
            .init(name: "Grid", value: Double(8 + day)),
            .init(name: "Solar", value: Double(12 - day)),
        ]
    )
}

#Preview {
    HAStatisticsGraphCard(
        title: "Energy",
        bars: sampleBars,
        colors: ["Grid": .haPrimary, "Solar": .haWarningColor],
        timeZone: TimeZone(identifier: "UTC") ?? .gmt
    )
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAStatisticsGraphCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-statistics-graph-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
