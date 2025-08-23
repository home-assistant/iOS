import CarPlay
import Foundation
import UIKit

public extension MaterialDesignIcons {
    func carPlayIcon(color: UIColor? = nil) -> UIImage {
        let color = color ?? .haPrimary
        return image(ofSize: CPListItem.maximumImageSize, color: color)
    }
}
