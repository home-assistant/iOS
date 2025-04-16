import CarPlay
import Foundation
import UIKit

public extension MaterialDesignIcons {
    func carPlayIcon(color: UIColor? = nil) -> UIImage {
        let color = color ?? Asset.Colors.haPrimary.color
        return image(ofSize: CPListItem.maximumImageSize, color: color)
    }
}
