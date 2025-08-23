import Foundation
import UIKit

extension UIScreen {
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
