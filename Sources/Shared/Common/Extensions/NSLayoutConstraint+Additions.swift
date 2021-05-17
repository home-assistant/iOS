import UIKit

public extension NSLayoutConstraint {
    static func aspectRatioConstraint(on view: UIView, size: CGSize) -> NSLayoutConstraint? {
        guard size.height > 0 else {
            return nil
        }

        let ratio = size.width / size.height
        return view.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: ratio)
    }
}
