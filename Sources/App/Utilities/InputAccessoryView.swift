import UIKit

class InputAccessoryView: UIView {
    init() {
        super.init(frame: .zero)
        autoresizingMask.insert(.flexibleHeight)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 0)
    }

    var contentView: UIView? {
        willSet {
            if let contentView = contentView, contentView != newValue, contentView.superview == self {
                contentView.removeFromSuperview()
            }
        }
        didSet {
            if let contentView = contentView {
                addSubview(contentView)

                NSLayoutConstraint.activate([
                    contentView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
                    contentView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
                    contentView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
                    contentView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
                ])
            }
        }
    }
}
