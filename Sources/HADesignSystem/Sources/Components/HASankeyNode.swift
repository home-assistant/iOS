#if !os(watchOS)
import Foundation
import SwiftUI

/// One box in an ``HASankeyChart``, mirroring the frontend's `Node`.
public struct HASankeyNode: Identifiable, Equatable {
    public let id: String
    public let value: Double
    /// Which column the node sits in. The frontend calls it `index` and describes it as "like
    /// z-index but for x/y": sources are 0, what they feed is 1, and so on.
    public let column: Int
    public let label: String?
    public let color: Color

    public init(id: String, value: Double, column: Int, label: String? = nil, color: Color = .haPrimary) {
        self.id = id
        self.value = value
        self.column = column
        self.label = label
        self.color = color
    }
}

extension HASankeyNode: FrontendComponent {
    public static var frontendComponentName: String { "ha-sankey-chart" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
