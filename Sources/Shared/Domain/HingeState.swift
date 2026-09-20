import Foundation

/// A reading of a folding device's hinge: how far open it is, and how the system classifies that.
public struct HingeState: Equatable, Sendable {
    /// The angle between the two halves of the device, in degrees.
    ///
    /// Degrees rather than the radians UIKit reports: this is what the sensor sends, and a
    /// Home Assistant dashboard showing 180 is worth more than one showing 3.14.
    public let angleDegrees: Double
    public let status: HingeStatus

    public init(angleDegrees: Double, status: HingeStatus) {
        self.angleDegrees = angleDegrees
        self.status = status
    }

    /// Builds a reading from the radians UIKit reports.
    public init(angleRadians: Double, status: HingeStatus) {
        self.init(angleDegrees: angleRadians * 180 / .pi, status: status)
    }

    /// Builds a reading straight from what `UIHinge` reports, which is radians and a raw status.
    public init(angleRadians: Double, uiKitStatusRawValue: Int) {
        self.init(angleRadians: angleRadians, status: HingeStatus(uiKitStatusRawValue: uiKitStatusRawValue))
    }
}
