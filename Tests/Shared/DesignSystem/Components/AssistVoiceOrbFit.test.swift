import CoreGraphics
@testable import HADesignSystem
import Testing

/// How the Assist orb fits a room smaller than its loudest activity circle. The watch hands it the
/// room left between the hints above and below it, which on the smallest watch is less than even the
/// orb at rest.
struct AssistVoiceOrbFitTests {
    private static let resting: CGFloat = 72
    private static let loudest: CGFloat = 115.2

    private func fit(_ maximumDiameter: CGFloat?) -> AssistVoiceOrbFit {
        AssistVoiceOrbFit(
            restingDiameter: Self.resting,
            loudestDiameter: Self.loudest,
            maximumDiameter: maximumDiameter
        )
    }

    @Test func withoutALimitTheOrbGrowsFully() {
        #expect(fit(nil) == .unconstrained)
    }

    @Test func roomForTheLoudestCircleLeavesTheOrbAlone() {
        #expect(fit(Self.loudest) == .unconstrained)
        #expect(fit(200) == .unconstrained)
    }

    /// Between the orb at rest and its loudest circle, the orb keeps its size and grows only as far as
    /// the room goes.
    @Test func lessRoomThanTheLoudestCircleCapsTheGrowth() {
        let halfway = fit((Self.resting + Self.loudest) / 2)
        #expect(halfway.scale == 1)
        #expect(abs(halfway.levelScale - 0.5) < 0.000_1)
    }

    @Test func lessRoomThanTheOrbAtRestShrinksItAndStopsItGrowing() {
        #expect(fit(Self.resting) == AssistVoiceOrbFit(scale: 1, levelScale: 0))
        #expect(fit(54) == AssistVoiceOrbFit(scale: 0.75, levelScale: 0))
    }

    @Test func noRoomLeavesNoOrb() {
        #expect(fit(0) == AssistVoiceOrbFit(scale: 0, levelScale: 0))
        #expect(fit(-10) == AssistVoiceOrbFit(scale: 0, levelScale: 0))
    }
}
