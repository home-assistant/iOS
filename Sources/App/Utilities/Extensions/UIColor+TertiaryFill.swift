import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension UIColor {
    /// The thin fill behind pills and badges: `tertiarySystemFill` wherever the system has it. AppKit only
    /// gained the fill colors in macOS 14, so earlier releases get the quaternary label color, which is
    /// what they tint thin fills with.
    static var tertiaryFill: UIColor {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            return .tertiarySystemFill
        } else {
            return .quaternaryLabelColor
        }
        #else
        return .tertiarySystemFill
        #endif
    }
}
