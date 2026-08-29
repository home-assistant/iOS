#if !os(watchOS)
import CoreGraphics
import Foundation

/// Turns sankey nodes and links into the boxes and ribbons to draw.
///
/// Split out of ``HASankeyChart`` for the same reason the slider scales are: a diagram of plausible
/// shapes looks right whether or not the flows add up. The rules that matter — every column scaled
/// to the same units, a link never wider than what its ends have left, ribbons leaving a node in
/// order without overlapping — are arithmetic, and arithmetic can be checked.
///
/// Frontend counterpart: the layout pass inside `chart/ha-sankey-chart`, which keeps it in the
/// element rather than apart from it.
public struct HASankeyLayout {
    /// A node's box.
    public struct Box: Equatable {
        public let id: String
        public let rect: CGRect
    }

    /// A flow, as the two edges it spans. The chart curves between them.
    public struct Ribbon: Equatable {
        public let source: String
        public let target: String
        /// Where the ribbon leaves the source: `x` is the source's trailing edge.
        public let start: CGRect
        /// Where it meets the target: `x` is the target's leading edge.
        public let end: CGRect
    }

    public static let nodeWidth: CGFloat = 12
    /// `NODE_GAP` in the frontend.
    public static let nodeGap: CGFloat = 6

    public let boxes: [Box]
    public let ribbons: [Ribbon]

    public init(nodes: [HASankeyNode], links: [HASankeyLink], size: CGSize) {
        let columns = Dictionary(grouping: nodes.filter { $0.value > 0 }, by: \.column)
            .sorted { $0.key < $1.key }

        guard !columns.isEmpty, size.width > 0, size.height > 0 else {
            boxes = []
            ribbons = []
            return
        }

        // Every column is drawn in the same units, so a node's height means the same thing wherever
        // it sits. The busiest column sets the scale and therefore fills the height.
        let tallestColumnTotal = columns.map { $0.value.reduce(0) { $0 + $1.value } }.max() ?? 0
        let mostNodesInAColumn = columns.map(\.value.count).max() ?? 1
        // The gaps can exceed the height the caller gave us — many nodes in a short chart — which
        // would make the scale negative and emit boxes and ribbons with negative heights. There is
        // no sensible diagram at that size, so draw nothing rather than something invalid.
        let availableHeight = size.height - Self.nodeGap * CGFloat(mostNodesInAColumn - 1)
        guard availableHeight > 0 else {
            boxes = []
            ribbons = []
            return
        }
        let scale = tallestColumnTotal > 0 ? availableHeight / tallestColumnTotal : 0

        let columnSpacing = columns.count > 1
            ? (size.width - Self.nodeWidth) / CGFloat(columns.count - 1)
            : 0

        var boxes: [Box] = []
        var rectsByID: [String: CGRect] = [:]
        for (columnIndex, column) in columns.enumerated() {
            var y: CGFloat = 0
            let x = columnSpacing * CGFloat(columnIndex)
            for node in column.value {
                let rect = CGRect(x: x, y: y, width: Self.nodeWidth, height: node.value * scale)
                boxes.append(Box(id: node.id, rect: rect))
                rectsByID[node.id] = rect
                y += rect.height + Self.nodeGap
            }
        }
        self.boxes = boxes

        // Ribbons stack down each node's edge in the order the links were given, so two flows out of
        // one node sit against each other rather than on top of each other.
        let valuesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.value) })
        var outgoingUsed: [String: Double] = [:]
        var incomingUsed: [String: Double] = [:]
        var ribbons: [Ribbon] = []

        for link in links {
            guard let sourceRect = rectsByID[link.source], let targetRect = rectsByID[link.target],
                  let sourceTotal = valuesByID[link.source], let targetTotal = valuesByID[link.target] else { continue }

            let sourceLeft = sourceTotal - (outgoingUsed[link.source] ?? 0)
            let targetLeft = targetTotal - (incomingUsed[link.target] ?? 0)
            // An unstated link takes whatever both ends can still spare; a stated one is still
            // capped by that, so a caller's numbers cannot draw a ribbon wider than its node.
            let value = Swift.max(0, Swift.min(
                link.value ?? Swift.min(sourceLeft, targetLeft),
                Swift.min(sourceLeft, targetLeft)
            ))
            guard value > 0 else { continue }

            let height = value * scale
            let start = CGRect(
                x: sourceRect.maxX,
                y: sourceRect.minY + (outgoingUsed[link.source] ?? 0) * scale,
                width: 0,
                height: height
            )
            let end = CGRect(
                x: targetRect.minX,
                y: targetRect.minY + (incomingUsed[link.target] ?? 0) * scale,
                width: 0,
                height: height
            )
            ribbons.append(Ribbon(source: link.source, target: link.target, start: start, end: end))
            outgoingUsed[link.source, default: 0] += value
            incomingUsed[link.target, default: 0] += value
        }
        self.ribbons = ribbons
    }
}

extension HASankeyLayout: FrontendComponent {
    public static var frontendComponentName: String { "ha-sankey-chart" }
}

#endif
