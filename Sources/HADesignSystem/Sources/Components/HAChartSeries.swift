#if !os(watchOS)
import Foundation
import SwiftUI

/// A named line of readings for ``HAHistoryChart``.
///
/// Distinct from `WidgetEnergyChartPoint`, which the energy widget uses: that one carries the
/// energy chart's own shape, where this is a plain time series any numeric history can fill.
///
/// Frontend counterpart: the data `chart/state-history-chart-line` is handed, rather than an
/// element of its own.
public struct HAChartSeries: Identifiable {
    /// One reading: when it was taken and what it read.
    public struct Point: Identifiable, Sendable {
        public let id: Date
        public let date: Date
        public let value: Double

        public init(date: Date, value: Double) {
            self.id = date
            self.date = date
            self.value = value
        }
    }

    public let id: String
    public let name: String
    public let color: Color
    public let points: [Point]

    public init(id: String, name: String, color: Color = .haPrimary, points: [Point]) {
        self.id = id
        self.name = name
        self.color = color
        self.points = points
    }
}

extension HAChartSeries: FrontendComponent {
    public static var frontendComponentName: String { "state-history-chart-line" }
}

#endif
