#if !os(watchOS)
import Foundation
import SwiftUI

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

#endif
