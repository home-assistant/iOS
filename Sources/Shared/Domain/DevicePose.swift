import Foundation

/// How a folding device is being held or stood, worked out from its hinge and its orientation.
///
/// `UIDeviceOrientation` describes the device in the frame of its outer display, where portrait
/// puts the hinge down the left edge. That is why a partially open device in portrait is a book,
/// and why the inner display, which spans both halves, is wider than tall in portrait and taller
/// than wide in landscape.
///
/// The raw values are the sensor's state, so they are API: renaming one renames the state Home
/// Assistant has been storing.
public enum DevicePose: String, CaseIterable, Sendable {
    case unknown
    case closed
    case book
    case laptop
    case tent
    case partiallyOpen = "partially_open"
    case flat
    case flatPortrait = "flat_portrait"
    case flatLandscape = "flat_landscape"
    case flatFaceDown = "flat_face_down"

    /// The smallest hinge angle, in degrees, that counts as open whatever the system's status says.
    ///
    /// UIKit keeps calling the hinge closed well after it has started to open: an iPhone Duo standing
    /// as a narrow tent reads 30° and closed. A shut device reads next to nothing, so anything past
    /// this is a device someone has opened.
    static let minimumOpenAngleDegrees: Double = 10

    public init(state: HingeState, uiDeviceOrientationRawValue orientation: Int) {
        switch state.status {
        case .unknown:
            self = .unknown
        case .closed where state.angleDegrees < Self.minimumOpenAngleDegrees:
            self = .closed
        case .fullyOpen:
            switch orientation {
            case UIDeviceOrientationRawValue.portrait, UIDeviceOrientationRawValue.portraitUpsideDown:
                // Hinge upright, so the open display is wider than tall.
                self = .flatLandscape
            case UIDeviceOrientationRawValue.landscapeLeft, UIDeviceOrientationRawValue.landscapeRight:
                // Hinge across, so the open display is taller than wide.
                self = .flatPortrait
            case UIDeviceOrientationRawValue.faceDown:
                self = .flatFaceDown
            default:
                self = .flat
            }
        case .closed, .partiallyOpen:
            switch orientation {
            case UIDeviceOrientationRawValue.portrait, UIDeviceOrientationRawValue.portraitUpsideDown:
                self = .book
            case UIDeviceOrientationRawValue.landscapeLeft:
                // The hinge edge points down: it is the fold between an upright half and the half
                // resting on the table.
                self = .laptop
            case UIDeviceOrientationRawValue.landscapeRight, UIDeviceOrientationRawValue.faceUp:
                // The hinge edge points up: it is the peak the two halves lean against. The wider
                // the tent, the further each half leans back, until iOS stops calling it sideways
                // and reports the outer display as facing up instead.
                self = .tent
            default:
                self = .partiallyOpen
            }
        }
    }

    private enum UIDeviceOrientationRawValue {
        static let portrait = 1
        static let portraitUpsideDown = 2
        static let landscapeLeft = 3
        static let landscapeRight = 4
        static let faceUp = 5
        static let faceDown = 6
    }
}
