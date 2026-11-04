#if !os(watchOS)
import Foundation
import SwiftUI

/// One bar of an ``HAStatisticsChart``: a period, and how much each source contributed to it.
///
/// The contributions are named so the chart can stack them and colour them consistently across
/// bars — a source that is absent from one period simply has no entry, rather than a zero.
///
/// Frontend counterpart: the data `chart/statistics-chart` is handed, rather than an element of
/// its own.
public struct HAStatisticsBar: Identifiable {
    public struct Contribution: Identifiable, Sendable {
        public var id: String { name }
        public let name: String
        public let value: Double

        public init(name: String, value: Double) {
            self.name = name
            self.value = value
        }
    }

    public var id: Date { date }
    public let date: Date
    public let contributions: [Contribution]

    public init(date: Date, contributions: [Contribution]) {
        self.date = date
        self.contributions = contributions
    }
}

extension HAStatisticsBar: FrontendComponent {
    public static var frontendComponentName: String { "statistics-chart" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
