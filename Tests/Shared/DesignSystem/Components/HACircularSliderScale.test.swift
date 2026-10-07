@testable import Shared
import Testing

/// The dial's angle maths and its dual-handle bounds, neither of which a snapshot can check — an arc
/// of some length looks the same whichever handle was clamped against what.
struct HACircularSliderScaleTests {
    @Test func angleSpansTheSweep() {
        let scale = HACircularSliderScale(min: 0, max: 100)
        #expect(scale.angle(for: 0) == 0)
        #expect(scale.angle(for: 50) == 135)
        #expect(scale.angle(for: 100) == HACircularSliderScale.sweepDegrees)
    }

    @Test func percentageClampsOutsideTheRange() {
        let scale = HACircularSliderScale(min: 7, max: 35)
        #expect(scale.percentage(for: 0) == 0)
        #expect(scale.percentage(for: 100) == 1)
    }

    /// Unlike the linear slider, snapping here does not clamp: the dial's bounds depend on the other
    /// handle, so clamping is a separate step.
    @Test func steppingDoesNotClamp() {
        let scale = HACircularSliderScale(min: 10, max: 20, step: 10)
        #expect(scale.stepped(24) == 20)
        #expect(scale.stepped(4) == 0)
    }

    @Test func steppingSnapsToHalves() {
        let scale = HACircularSliderScale(min: 7, max: 35, step: 0.5)
        #expect(scale.stepped(21.3) == 21.5)
        #expect(scale.stepped(21.1) == 21)
    }

    @Test func lowHandleStopsAtTheHighOne() {
        let scale = HACircularSliderScale(min: 7, max: 35)
        #expect(scale.boundedLow(30, high: 24) == 24)
        #expect(scale.boundedLow(18, high: 24) == 18)
        #expect(scale.boundedLow(0, high: 24) == 7)
    }

    @Test func highHandleStopsAtTheLowOne() {
        let scale = HACircularSliderScale(min: 7, max: 35)
        #expect(scale.boundedHigh(12, low: 18) == 18)
        #expect(scale.boundedHigh(24, low: 18) == 24)
        #expect(scale.boundedHigh(99, low: 18) == 35)
    }

    /// With no sibling handle the range's own bounds apply.
    @Test func aLoneHandleUsesTheRange() {
        let scale = HACircularSliderScale(min: 7, max: 35)
        #expect(scale.boundedLow(99, high: nil) == 35)
        #expect(scale.boundedHigh(0, low: nil) == 7)
    }

    @Test func emptyRangeReadsAsZero() {
        let scale = HACircularSliderScale(min: 5, max: 5)
        #expect(scale.percentage(for: 5) == 0)
        #expect(scale.angle(for: 5) == 0)
    }
}
