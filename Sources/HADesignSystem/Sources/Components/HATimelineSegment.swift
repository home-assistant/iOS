#if !os(watchOS)
import Foundation
import SwiftUI

/// One stretch of time an entity spent in a state, for ``HAHistoryTimeline``.
///
/// Frontend counterpart: the data `chart/state-history-chart-timeline` is handed, rather than an
/// element of its own.
public struct HATimelineSegment: Identifiable, Sendable {
    public var id: Date { start }
    public let start: Date
    public let end: Date
    public let label: String
    public let color: Color

    public init(start: Date, end: Date, label: String, color: Color) {
        self.start = start
        self.end = end
        self.label = label
        self.color = color
    }

    /// Seconds the entity held this state, used to size the band.
    public var duration: TimeInterval {
        Swift.max(0, end.timeIntervalSince(start))
    }
}

extension HATimelineSegment: FrontendComponent {
    public static var frontendComponentName: String { "state-history-chart-timeline" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
