import Foundation
import UIKit

public extension UIFont {
    static func roboto(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        switch weight {
        case .medium:
            return UIFont(name: "Roboto-Medium", size: size)!
        default:
            return UIFont(name: "Roboto-Regular", size: size)!
        }
    }
}
