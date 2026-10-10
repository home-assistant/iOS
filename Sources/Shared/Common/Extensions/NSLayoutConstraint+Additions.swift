#if os(macOS)
import AppKit
#else
import UIKit
#endif

public extension NSLayoutConstraint {
    #if os(macOS)
    static func aspectRatioConstraint(on view: NSView, size: CGSize) -> NSLayoutConstraint? {
        aspectRatioConstraint(width: view.widthAnchor, height: view.heightAnchor, size: size)
    }
    #else
    static func aspectRatioConstraint(on view: UIView, size: CGSize) -> NSLayoutConstraint? {
        aspectRatioConstraint(width: view.widthAnchor, height: view.heightAnchor, size: size)
    }
    #endif

    private static func aspectRatioConstraint(
        width: NSLayoutDimension,
        height: NSLayoutDimension,
        size: CGSize
    ) -> NSLayoutConstraint? {
        guard size.height > 0 else {
            return nil
        }

        let ratio = size.width / size.height
        return width.constraint(equalTo: height, multiplier: ratio)
    }
}
