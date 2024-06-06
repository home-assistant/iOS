import Foundation
import Shared
import UIKit

extension UIImage {
    func scaledToSize(_ size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(
            size: size,
            format: with(UIGraphicsImageRendererFormat.preferred()) {
                $0.opaque = imageRendererFormat.opaque
            }
        ).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
