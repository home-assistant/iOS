import UIKit

/// Stand-in source for the zoom transition into Assist.
///
/// Assist opened from the frontend arrives over the external bus, so — unlike a native button — there is no
/// view the user touched for `UIViewController.Transition.zoom` to grow out of, and a zoom with no source
/// falls back to a plain full-screen presentation. This is that missing view: an empty, non-interactive anchor
/// parked in the frontend's top trailing corner, where its toolbar draws the Assist button, so the transition
/// starts from roughly where the tap came from.
///
/// It draws nothing and takes no touches; only its frame matters. It stays in the hierarchy rather than being
/// hidden between presentations because the transition needs a source view that is visible and in a window.
final class AssistZoomAnchorView: UIView {
    /// Matches the frontend toolbar's icon buttons: a 40pt tap target, inset from the trailing edge and
    /// vertically centered in the 56pt toolbar that starts at the top of the safe area.
    static let size = CGSize(width: 40, height: 40)
    static let trailingInset: CGFloat = 8
    static let topInset: CGFloat = 8

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

    /// Adds an anchor to `container`, pinned to the top trailing corner of its safe area. Trailing rather than
    /// right so it follows the layout direction, as the frontend's own toolbar does.
    @discardableResult
    static func install(in container: UIView) -> AssistZoomAnchorView {
        let anchor = AssistZoomAnchorView(frame: .init(origin: .zero, size: size))
        anchor.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(anchor)

        NSLayoutConstraint.activate([
            anchor.widthAnchor.constraint(equalToConstant: size.width),
            anchor.heightAnchor.constraint(equalToConstant: size.height),
            anchor.trailingAnchor.constraint(
                equalTo: container.safeAreaLayoutGuide.trailingAnchor,
                constant: -trailingInset
            ),
            anchor.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: topInset),
        ])

        return anchor
    }
}
