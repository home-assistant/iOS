import SwiftUI

/// A coloured band on an ``HAGauge``, mirroring the frontend's `LevelDefinition`.
///
/// `level` is where the band *starts*; it runs until the next level begins, or to the gauge's
/// maximum for the last one. Levels are sorted before drawing, so callers need not pass them in
/// order.
public struct HAGaugeLevel: Identifiable, Equatable, Sendable {
    public var id: Double { level }
    public let level: Double
    public let color: Color

    public init(level: Double, color: Color) {
        self.level = level
        self.color = color
    }
}

extension HAGaugeLevel: FrontendComponent {
    public static var frontendComponentName: String { "ha-gauge" }
}
