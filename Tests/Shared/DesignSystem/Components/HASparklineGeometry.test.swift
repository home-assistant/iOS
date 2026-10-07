import CoreGraphics
@testable import HADesignSystem
import Testing

/// The curve `get-path.ts` builds. A sparkline of plausible shape looks right whether or not it is
/// the right shape, so the arithmetic is pinned here rather than left to the snapshot.
struct HASparklineGeometryTests {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 50)

    @Test func readingsSpreadEvenlyAcrossTheWidth() {
        let points = HASparklineGeometry.points(for: [0, 1, 2, 3, 4], in: rect)
        #expect(points.map(\.x) == [0, 25, 50, 75, 100])
    }

    /// A view's y grows downward, so the highest reading has to land at the *smallest* y or the
    /// line comes out upside down.
    @Test func theHighestReadingIsAtTheTop() {
        let points = HASparklineGeometry.points(for: [10, 20], in: rect)
        #expect(points[0].y == rect.maxY)
        #expect(points[1].y == rect.minY)
    }

    @Test func readingsScaleToTheirOwnRangeNotToZero() {
        // 100…102 fills the height the same way 0…2 would; a sparkline shows shape, not magnitude.
        let points = HASparklineGeometry.points(for: [100, 101, 102], in: rect)
        #expect(points[0].y == rect.maxY)
        #expect(points[1].y == rect.midY)
        #expect(points[2].y == rect.minY)
    }

    /// Every reading equal leaves no range to divide by. The frontend would produce NaN; this puts
    /// the line at the centre instead.
    @Test func aFlatRunSitsAtTheVerticalCentre() {
        let points = HASparklineGeometry.points(for: [7, 7, 7], in: rect)
        // Hoisted out of `#expect`: SwiftFormat rewrites the closure to a key path, which the macro
        // expansion cannot typecheck as non-throwing.
        let allFinite = points.allSatisfy(\.y.isFinite)
        #expect(points.allSatisfy { $0.y == rect.midY })
        #expect(allFinite)
    }

    @Test func noReadingsProduceNoPoints() {
        #expect(HASparklineGeometry.points(for: [], in: rect).isEmpty)
    }

    @Test func oneReadingSitsAtTheCentre() {
        let points = HASparklineGeometry.points(for: [5], in: rect)
        #expect(points == [CGPoint(x: rect.midX, y: rect.midY)])
    }

    /// The frontend's smoothing: each reading is a *control* point and the curve passes through the
    /// midpoints between readings. That is what keeps the line from overshooting past a spike.
    @Test func eachSegmentEndsAtTheMidpointBetweenReadings() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 20), CGPoint(x: 20, y: 0)]
        let segments = HASparklineGeometry.segments(for: points)
        #expect(segments.count == 3)
        #expect(segments[0].control == CGPoint(x: 0, y: 0))
        #expect(segments[0].end == CGPoint(x: 5, y: 10))
        #expect(segments[1].control == CGPoint(x: 10, y: 20))
        #expect(segments[1].end == CGPoint(x: 15, y: 10))
    }

    /// The last segment has no next reading to average with, so it ends on the reading itself —
    /// otherwise the line would stop short of its final value.
    @Test func theLastSegmentEndsOnTheFinalReading() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 20)]
        let segments = HASparklineGeometry.segments(for: points)
        #expect(segments.last?.end == CGPoint(x: 10, y: 20))
        #expect(segments.last?.control == CGPoint(x: 10, y: 20))
    }

    @Test func fewerThanTwoPointsMakeNoCurve() {
        #expect(HASparklineGeometry.segments(for: []).isEmpty)
        #expect(HASparklineGeometry.segments(for: [CGPoint(x: 1, y: 1)]).isEmpty)
    }
}
