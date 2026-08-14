import Foundation

#if os(iOS)
import UIKit

public extension UIScreen {
    /// The screen's current rotation, expressed as the equivalent device orientation.
    ///
    /// Unlike `UIDevice.current.orientation` this is derived from the screen geometry,
    /// so it stays meaningful when the device itself reports `.faceUp`, `.faceDown` or
    /// `.unknown` — the usual case for a flat or wall-mounted tablet.
    var orientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(CGPoint.zero, to: fixedCoordinateSpace)
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0, point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0, point.y != 0 {
            return .landscapeRight
        } else if point.x != 0, point.y == 0 {
            return .landscapeLeft
        } else {
            return .unknown
        }
    }
}
#endif
