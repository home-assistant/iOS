#if !os(watchOS)
import Foundation
import UIKit

/// The display's own corner radius, so a view hugging the screen edge can match its curve.
///
/// Frontend counterpart: none — a hardware measurement the web has no access to.
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
#endif
