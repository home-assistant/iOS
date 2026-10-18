@testable import Shared
import Testing

/// The slider's value maths, which a snapshot cannot check: a bar of a given length looks the same
/// whether the value behind it was clamped and snapped correctly or not.
struct HASliderScaleTests {
    @Test func percentageSpansTheRange() {
        let scale = HASliderScale(min: 0, max: 100)
        #expect(scale.percentage(for: 0) == 0)
        #expect(scale.percentage(for: 50) == 0.5)
        #expect(scale.percentage(for: 100) == 1)
    }

    @Test func percentageClampsOutsideTheRange() {
        let scale = HASliderScale(min: 10, max: 20)
        #expect(scale.percentage(for: -5) == 0)
        #expect(scale.percentage(for: 999) == 1)
    }

    @Test func invertedRunsTheOtherWay() {
        let scale = HASliderScale(min: 0, max: 100, inverted: true)
        #expect(scale.percentage(for: 0) == 1)
        #expect(scale.percentage(for: 100) == 0)
        #expect(scale.value(atPercentage: 0) == 100)
        #expect(scale.value(atPercentage: 1) == 0)
    }

    @Test func valueAndPercentageRoundTrip() {
        let scale = HASliderScale(min: 10, max: 30)
        #expect(scale.value(atPercentage: scale.percentage(for: 25)) == 25)
    }

    /// The frontend clamps *after* snapping for exactly this case: with a step that does not divide
    /// the range, snapping alone pushes the ends past the bounds.
    @Test func steppingClampsAfterSnapping() {
        let scale = HASliderScale(min: 1, max: 99, step: 10)
        #expect(scale.stepped(1) == 1)
        #expect(scale.stepped(99) == 99)
        #expect(scale.stepped(46) == 50)
    }

    @Test func steppingSnapsToTheNearestStep() {
        let scale = HASliderScale(min: 0, max: 100, step: 5)
        #expect(scale.stepped(12) == 10)
        #expect(scale.stepped(13) == 15)
    }

    /// A step of zero would divide by zero; the value should just be clamped instead.
    @Test func zeroStepOnlyClamps() {
        let scale = HASliderScale(min: 0, max: 10, step: 0)
        #expect(scale.stepped(4.2) == 4.2)
        #expect(scale.stepped(50) == 10)
    }

    /// A zero-width range has no position to report, and must not divide by zero.
    @Test func emptyRangeReadsAsZero() {
        let scale = HASliderScale(min: 5, max: 5)
        #expect(scale.percentage(for: 5) == 0)
    }

    @Test func largeStepIsATenthOfTheRangeOrTheStep() {
        #expect(HASliderScale(min: 0, max: 100, step: 1).largeStep == 10)
        // A step coarser than a tenth wins, so the large step never moves less than a small one.
        #expect(HASliderScale(min: 0, max: 100, step: 25).largeStep == 25)
    }
}
