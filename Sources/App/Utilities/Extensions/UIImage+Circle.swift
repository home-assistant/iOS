import CoreGraphics
import Foundation
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension UIImage {
    func croppedToCircle() -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let radius = size.width / 2

        #if os(macOS)
        return UIGraphicsImageRenderer(size: size, scale: scale).image { _ in
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
            draw(in: rect)
        }
        #else
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        format.opaque = false
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
            draw(in: rect)
        }
        #endif
    }
}
