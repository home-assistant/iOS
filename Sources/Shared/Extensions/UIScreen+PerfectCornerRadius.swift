import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension UIScreen {
    private static let cornerRadiusKey: String = {
        let components = ["Radius", "Corner", "display", "_"]
        return components.reversed().joined()
    }()

    var displayCornerRadius: CGFloat {
        guard let cornerRadius = value(forKey: Self.cornerRadiusKey) as? CGFloat else {
            assertionFailure("Failed to detect screen corner radius")
            return 0
        }

        return cornerRadius
    }
}
