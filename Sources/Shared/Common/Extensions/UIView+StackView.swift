import UIKit
#if os(iOS)

public extension UIView {
    struct EqualSpacers {
        private let layoutGuide: UILayoutGuide

        init(containerView: UIView) {
            self.layoutGuide = UILayoutGuide()
            containerView.addLayoutGuide(layoutGuide)
        }

        private class SpacerView: UIView {
            let laterGuide: UILayoutGuide
            init(laterGuide: UILayoutGuide) {
                self.laterGuide = laterGuide
                super.init(frame: .zero)
                setContentHuggingPriority(.defaultLow, for: .vertical)
                setContentHuggingPriority(.defaultLow, for: .horizontal)
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) { fatalError() }
            override func didMoveToSuperview() {
                super.didMoveToSuperview()
                if let superview = superview, superview.layoutGuides.contains(laterGuide) {
                    heightAnchor.constraint(equalTo: laterGuide.heightAnchor).isActive = true
                }
            }
        }

        public func next() -> UIView {
            SpacerView(laterGuide: layoutGuide)
        }
    }

    static func contentStackView(in superview: UIView, scrolling: Bool) -> (UIScrollView?, UIStackView, EqualSpacers) {
        let stackView = with(UIStackView()) {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.axis = .vertical
            $0.alignment = .center
            $0.spacing = 16
            $0.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            $0.isLayoutMarginsRelativeArrangement = true
        }

        let equalSpacers = EqualSpacers(containerView: stackView)

        if scrolling {
            let scrollView = with(UIScrollView()) {
                $0.contentInsetAdjustmentBehavior = .always
                $0.translatesAutoresizingMaskIntoConstraints = false
                $0.delaysContentTouches = false
            }

            superview.addSubview(scrollView)
            scrollView.addSubview(stackView)

            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: superview.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
                stackView.widthAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.widthAnchor),
                stackView.heightAnchor.constraint(greaterThanOrEqualTo: superview.safeAreaLayoutGuide.heightAnchor),

                stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            ])

            return (scrollView, stackView, equalSpacers)
        } else {
            superview.addSubview(stackView)
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                stackView.topAnchor.constraint(equalTo: superview.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
            ])
            return (nil, stackView, equalSpacers)
        }
    }
}

#endif
