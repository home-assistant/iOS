import CarPlay
import Foundation
import Shared
import UIKit

extension MaterialDesignIcons {
    func carPlayIcon(color: UIColor? = nil, carUserInterfaceStyle: UIUserInterfaceStyle? = nil) -> UIImage {
        let color: UIColor = color ?? {
            if let carUserInterfaceStyle, carUserInterfaceStyle == .light {
                .black
            } else {
                .white
            }
        }()
        return image(ofSize: CPListItem.maximumImageSize, color: color)
    }
}
