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

/// A flow from one node to another, mirroring the frontend's `Link`.
public struct HASankeyLink: Equatable {
    public let source: String
    public let target: String
    /// How much flows. Left `nil`, the layout infers it from what the two nodes have left
    /// unallocated — the frontend does the same, so a caller that knows the totals need not also
    /// state every link.
    public let value: Double?

    public init(source: String, target: String, value: Double? = nil) {
        self.source = source
        self.target = target
        self.value = value
    }
}

extension HASankeyNode: FrontendComponent {
    public static var frontendComponentName: String { "ha-sankey-chart" }
}

#endif
