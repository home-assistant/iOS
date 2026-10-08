import Foundation

public enum DevicePose: String, CaseIterable, Sendable {
    case unknown
    case closed
    case book
    case laptop
    case partiallyOpen = "partially_open"
    case flat
    case flatFaceDown = "flat_face_down"

    public init(status: HingeStatus, uiDeviceOrientationRawValue orientation: Int) {
        switch status {
        case .unknown:
            self = .unknown
        case .closed:
            self = .closed
        case .fullyOpen:
            self = orientation == UIDeviceOrientationRawValue.faceDown ? .flatFaceDown : .flat
        case .partiallyOpen:
            switch orientation {
            case UIDeviceOrientationRawValue.portrait, UIDeviceOrientationRawValue.portraitUpsideDown:
                self = .laptop
            case UIDeviceOrientationRawValue.landscapeLeft, UIDeviceOrientationRawValue.landscapeRight:
                self = .book
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
        static let faceDown = 6
    }
}
