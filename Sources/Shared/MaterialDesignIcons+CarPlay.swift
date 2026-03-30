import CarPlay
import Foundation
import UIKit

public extension MaterialDesignIcons {
    func carPlayIcon(color: UIColor? = nil) -> UIImage {
        let color = color ?? .haPrimary
        return image(ofSize: CPListItem.maximumImageSize, color: color)
    }

    func carPlayGridIcon(color: UIColor? = nil) -> UIImage {
        let color = color ?? .haPrimary
        let size: CGSize

        if #available(iOS 26.0, *) {
            size = CPListTemplate.maximumGridButtonImageSize
        } else {
            size = CGSize(width: 60, height: 60)
        }

        return image(ofSize: size, color: color)
    }
}
