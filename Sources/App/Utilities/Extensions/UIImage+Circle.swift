import CoreGraphics
import Foundation
import UIKit

extension UIImage {
    func croppedToCircle() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)

        let circleWidth = size.width
        let radius = circleWidth / 2

        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
        draw(in: rect)

        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let newImage {
            return newImage
        } else {
            return self
        }
    }
}
