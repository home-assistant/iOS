import Foundation
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension UIImage {
    func scaledToSize(_ size: CGSize) -> UIImage {
        #if os(macOS)
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        #else
        return UIGraphicsImageRenderer(
            size: size,
            format: with(UIGraphicsImageRendererFormat.preferred()) {
                $0.opaque = imageRendererFormat.opaque
            }
        ).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        #endif
    }
}
