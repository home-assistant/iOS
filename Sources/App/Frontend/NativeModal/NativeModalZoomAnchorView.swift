import UIKit

/// Stand-in source for the zoom transition into a native modal.
///
/// A modal asked for over the external bus has no view the user touched for
/// `UIViewController.Transition.zoom` to grow out of, and a zoom with no source falls back to a
/// plain presentation. The frontend sends the rectangle it was asked from instead, and this is the
/// view parked there: it draws nothing and takes no touches, only its frame matters. It lives in the
/// web view so the frontend's own coordinates need no translating, and it stays in the hierarchy
/// between presentations because the transition needs a source that is visible and in a window.
final class NativeModalZoomAnchorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
