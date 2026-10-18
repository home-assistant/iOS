@testable import Shared
import SwiftUI
import Testing

/// The sunburst's arithmetic: whether the slices add up, and whether children divide their parent
/// rather than the whole circle. A ring of plausible wedges looks right either way.
struct HASunburstLayoutTests {
    @Test func aSingleSegmentFillsTheCircle() {
        let layout = HASunburstLayout(segments: [
            HASunburstSegment(id: "a", name: "A", value: 10),
        ])
        #expect(layout.arcs.count == 1)
        #expect(layout.arcs[0].startAngle == .degrees(0))
        #expect(layout.arcs[0].endAngle == .degrees(360))
        #expect(layout.ringCount == 1)
    }

    @Test func siblingsSplitTheCircleByValue() {
        let layout = HASunburstLayout(segments: [
            HASunburstSegment(id: "a", name: "A", value: 30),
            HASunburstSegment(id: "b", name: "B", value: 10),
        ])
        #expect(layout.arcs[0].endAngle == .degrees(270))
        #expect(layout.arcs[1].startAngle == .degrees(270))
        #expect(layout.arcs[1].endAngle == .degrees(360))
    }

    /// The point of a sunburst: a child's span is carved out of its parent's, not out of the circle.
    @Test func childrenDivideTheirParentsSpan() {
        let layout = HASunburstLayout(segments: [
            HASunburstSegment(id: "a", name: "A", value: 50, children: [
                HASunburstSegment(id: "a1", name: "A1", value: 1),
                HASunburstSegment(id: "a2", name: "A2", value: 1),
            ]),
            HASunburstSegment(id: "b", name: "B", value: 50),
        ])
        let a1 = layout.arcs.first { $0.id == "a1" }!
        let a2 = layout.arcs.first { $0.id == "a2" }!
        #expect(a1.ring == 1)
        #expect(a1.startAngle == .degrees(0))
        #expect(a1.endAngle == .degrees(90))
        #expect(a2.endAngle == .degrees(180))
    }

    /// Children need not add up to their parent — they still fill its wedge, so a partial breakdown
    /// does not distort the ring outside it.
    @Test func childrenFillTheParentWhateverTheySumTo() {
        let layout = HASunburstLayout(segments: [
            HASunburstSegment(id: "a", name: "A", value: 100, children: [
                HASunburstSegment(id: "a1", name: "A1", value: 1),
            ]),
        ])
        let a1 = layout.arcs.first { $0.id == "a1" }!
        #expect(a1.startAngle == .degrees(0))
        #expect(a1.endAngle == .degrees(360))
    }

    @Test func ringCountIsTheDepthOfTheTree() {
        let layout = HASunburstLayout(segments: [
            HASunburstSegment(id: "a", name: "A", value: 1, children: [
                HASunburstSegment(id: "b", name: "B", value: 1, children: [
                    HASunburstSegment(id: "c", name: "C", value: 1),
                ]),
            ]),
        ])
        #expect(layout.ringCount == 3)
    }

    @Test func worthlessSegmentsAreLeftOut() {
        let layout = HASunburstLayout(segments: [
            HASunburstSegment(id: "a", name: "A", value: 10),
            HASunburstSegment(id: "b", name: "B", value: 0),
        ])
        #expect(layout.arcs.count == 1)
        #expect(layout.arcs[0].id == "a")
    }

    /// An empty tree, or one worth nothing at all, must not divide by zero.
    @Test func emptyInputProducesNothing() {
        #expect(HASunburstLayout(segments: []).arcs.isEmpty)
        #expect(HASunburstLayout(segments: []).ringCount == 0)
        #expect(HASunburstLayout(segments: [HASunburstSegment(id: "a", name: "A", value: 0)]).arcs.isEmpty)
    }
}
