import CoreGraphics
@testable import Shared
import Testing

/// The sankey's arithmetic. A diagram of plausible shapes looks right whether or not the flows add
/// up, so what is checked here is that they do.
struct HASankeyLayoutTests {
    private let size = CGSize(width: 200, height: 100)

    private func layout(
        nodes: [HASankeyNode],
        links: [HASankeyLink]
    ) -> HASankeyLayout {
        HASankeyLayout(nodes: nodes, links: links, size: size)
    }

    @Test func aSingleColumnFillsTheHeight() {
        let result = layout(
            nodes: [HASankeyNode(id: "a", value: 10, column: 0)],
            links: []
        )
        #expect(result.boxes.count == 1)
        #expect(result.boxes[0].rect.height == 100)
    }

    /// Two nodes sharing a column split the height in proportion, less the gap between them.
    @Test func nodesInAColumnSplitTheHeightByValue() {
        let result = layout(
            nodes: [
                HASankeyNode(id: "a", value: 30, column: 0),
                HASankeyNode(id: "b", value: 10, column: 0),
            ],
            links: []
        )
        let available = 100 - HASankeyLayout.nodeGap
        #expect(abs(result.boxes[0].rect.height - available * 0.75) < 0.001)
        #expect(abs(result.boxes[1].rect.height - available * 0.25) < 0.001)
        #expect(result.boxes[1].rect.minY == result.boxes[0].rect.maxY + HASankeyLayout.nodeGap)
    }

    /// Both columns are drawn in the same units, so a node worth the same is the same height
    /// wherever it sits — that is what makes the widths comparable across the diagram.
    @Test func columnsShareOneScale() {
        let result = layout(
            nodes: [
                HASankeyNode(id: "a", value: 10, column: 0),
                HASankeyNode(id: "b", value: 5, column: 1),
            ],
            links: []
        )
        let a = result.boxes.first { $0.id == "a" }!
        let b = result.boxes.first { $0.id == "b" }!
        #expect(abs(b.rect.height - a.rect.height / 2) < 0.001)
    }

    @Test func columnsAreLaidOutLeftToRight() {
        let result = layout(
            nodes: [
                HASankeyNode(id: "a", value: 10, column: 0),
                HASankeyNode(id: "b", value: 10, column: 1),
            ],
            links: []
        )
        let a = result.boxes.first { $0.id == "a" }!
        let b = result.boxes.first { $0.id == "b" }!
        #expect(a.rect.minX == 0)
        #expect(b.rect.maxX == size.width)
    }

    /// An unstated link takes what both ends have spare, which is the whole node when it has only
    /// one connection.
    @Test func anUnstatedLinkTakesTheSpareCapacity() {
        let result = layout(
            nodes: [
                HASankeyNode(id: "a", value: 10, column: 0),
                HASankeyNode(id: "b", value: 10, column: 1),
            ],
            links: [HASankeyLink(source: "a", target: "b")]
        )
        #expect(result.ribbons.count == 1)
        #expect(abs(result.ribbons[0].start.height - 100) < 0.001)
    }

    /// Two flows out of one node stack down its edge rather than overlapping.
    @Test func ribbonsStackDownANodesEdge() {
        let result = layout(
            nodes: [
                HASankeyNode(id: "a", value: 10, column: 0),
                HASankeyNode(id: "b", value: 5, column: 1),
                HASankeyNode(id: "c", value: 5, column: 1),
            ],
            links: [
                HASankeyLink(source: "a", target: "b", value: 5),
                HASankeyLink(source: "a", target: "c", value: 5),
            ]
        )
        #expect(result.ribbons.count == 2)
        #expect(result.ribbons[1].start.minY == result.ribbons[0].start.maxY)
    }

    /// A caller's number cannot draw a ribbon wider than the node it leaves.
    @Test func aLinkIsCappedByItsEnds() {
        let result = layout(
            nodes: [
                HASankeyNode(id: "a", value: 10, column: 0),
                HASankeyNode(id: "b", value: 10, column: 1),
            ],
            links: [HASankeyLink(source: "a", target: "b", value: 999)]
        )
        let boxHeight = result.boxes.first { $0.id == "a" }!.rect.height
        #expect(abs(result.ribbons[0].start.height - boxHeight) < 0.001)
    }

    /// A node with nothing left to give produces no ribbon rather than a zero-height sliver.
    @Test func anExhaustedNodeYieldsNoRibbon() {
        let result = layout(
            nodes: [
                HASankeyNode(id: "a", value: 10, column: 0),
                HASankeyNode(id: "b", value: 10, column: 1),
                HASankeyNode(id: "c", value: 10, column: 1),
            ],
            links: [
                HASankeyLink(source: "a", target: "b", value: 10),
                HASankeyLink(source: "a", target: "c", value: 10),
            ]
        )
        #expect(result.ribbons.count == 1)
    }

    @Test func linksToMissingNodesAreDropped() {
        let result = layout(
            nodes: [HASankeyNode(id: "a", value: 10, column: 0)],
            links: [HASankeyLink(source: "a", target: "nowhere")]
        )
        #expect(result.ribbons.isEmpty)
    }

    /// Nodes worth nothing are left out, as the frontend filters them, and an empty diagram must not
    /// divide by zero.
    @Test func emptyInputProducesNothing() {
        #expect(layout(nodes: [], links: []).boxes.isEmpty)
        #expect(layout(nodes: [HASankeyNode(id: "a", value: 0, column: 0)], links: []).boxes.isEmpty)
    }
}
