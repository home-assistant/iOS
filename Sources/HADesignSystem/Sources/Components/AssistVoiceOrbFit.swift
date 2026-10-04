import CoreGraphics

/// How `AssistVoiceOrbView` fits a room smaller than its loudest activity circle: the circle grows
/// less, so even the loudest level stays inside the room, and the orb itself shrinks only when the
/// room is smaller than the orb at rest.
struct AssistVoiceOrbFit: Equatable {
    /// Applied to the whole orb. Below 1 only when the room is smaller than the orb at rest.
    let scale: CGFloat
    /// Applied to the level the orb reacts to, so its growth tops out at the room's edge.
    let levelScale: Double

    static let unconstrained = AssistVoiceOrbFit(scale: 1, levelScale: 1)

    init(scale: CGFloat, levelScale: Double) {
        self.scale = scale
        self.levelScale = levelScale
    }

    /// - Parameters:
    ///   - restingDiameter: How much room the orb takes at level 0.
    ///   - loudestDiameter: How much room the orb takes at level 1. It grows linearly in between.
    ///   - maximumDiameter: The room there is, or `nil` for as much as the orb wants.
    init(restingDiameter: CGFloat, loudestDiameter: CGFloat, maximumDiameter: CGFloat?) {
        guard let maximumDiameter, maximumDiameter < loudestDiameter else {
            self = .unconstrained
            return
        }
        guard maximumDiameter > restingDiameter else {
            self.init(scale: max(0, maximumDiameter) / restingDiameter, levelScale: 0)
            return
        }
        self.init(
            scale: 1,
            levelScale: Double((maximumDiameter - restingDiameter) / (loudestDiameter - restingDiameter))
        )
    }
}
