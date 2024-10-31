import CarPlay
import Foundation
import Shared
import UIKit

extension MaterialDesignIcons {
    func carPlayIcon(color: UIColor? = nil) -> UIImage {
        let color = color ?? Asset.Colors.haPrimary.color
        return image(ofSize: CPListItem.maximumImageSize, color: color)
    }
}
