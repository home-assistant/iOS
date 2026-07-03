import Shared
import UIKit

final class ProgressHUD: UIView {
    enum Mode {
        case indeterminate
        case text
        case customView
    }

    enum BackgroundStyle {
        case solidColor
        case blur
    }

    final class BackgroundView: UIView {
        var style: BackgroundStyle = .solidColor {
            didSet { applyStyle() }
        }

        private var blurView: UIVisualEffectView?

        private func applyStyle() {
            switch style {
            case .solidColor:
                blurView?.removeFromSuperview()
                blurView = nil
                backgroundColor = .clear
            case .blur:
                guard blurView == nil else { return }
                backgroundColor = .clear
                let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                view.frame = bounds
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(view)
                blurView = view
            }
        }
    }

    let label = HUDLabel()
    let backgroundView = BackgroundView()

    var mode: Mode = .indeterminate {
        didSet { updateContent() }
    }

    var customView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let customView {
                customView.translatesAutoresizingMaskIntoConstraints = false
                customViewContainer.addSubview(customView)
                NSLayoutConstraint.activate([
                    customView.topAnchor.constraint(equalTo: customViewContainer.topAnchor),
                    customView.bottomAnchor.constraint(equalTo: customViewContainer.bottomAnchor),
                    customView.leadingAnchor.constraint(equalTo: customViewContainer.leadingAnchor),
                    customView.trailingAnchor.constraint(equalTo: customViewContainer.trailingAnchor),
                    customView.widthAnchor.constraint(equalToConstant: customView.frame.width),
                    customView.heightAnchor.constraint(equalToConstant: customView.frame.height),
                ])
            }
            updateContent()
        }
    }

    private let bezelView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    private let contentStack = UIStackView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let customViewContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    static func showAdded(to view: UIView, animated: Bool) -> ProgressHUD {
        let hud = ProgressHUD(frame: view.bounds)
        hud.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hud)
        hud.show(animated: animated)
        return hud
    }

    func hide(animated: Bool) {
        let removal = { self.removeFromSuperview() }
        if animated {
            UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in removal() }
        } else {
            removal()
        }
    }

    func hide(animated: Bool, afterDelay delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.hide(animated: animated)
        }
    }

    private func setup() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        bezelView.translatesAutoresizingMaskIntoConstraints = false
        bezelView.layer.cornerRadius = DesignSystem.CornerRadius.two
        bezelView.layer.cornerCurve = .continuous
        bezelView.clipsToBounds = true
        addSubview(bezelView)

        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = DesignSystem.Spaces.two
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        bezelView.contentView.addSubview(contentStack)

        activityIndicator.startAnimating()
        customViewContainer.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .headline)
        label.onTextChange = { [weak self] in self?.updateContent() }

        contentStack.addArrangedSubview(activityIndicator)
        contentStack.addArrangedSubview(customViewContainer)
        contentStack.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),

            bezelView.centerXAnchor.constraint(equalTo: centerXAnchor),
            bezelView.centerYAnchor.constraint(equalTo: centerYAnchor),

            contentStack.topAnchor.constraint(
                equalTo: bezelView.contentView.topAnchor,
                constant: DesignSystem.Spaces.two
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: bezelView.contentView.bottomAnchor,
                constant: -DesignSystem.Spaces.two
            ),
            contentStack.leadingAnchor.constraint(
                equalTo: bezelView.contentView.leadingAnchor,
                constant: DesignSystem.Spaces.two
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: bezelView.contentView.trailingAnchor,
                constant: -DesignSystem.Spaces.two
            ),
        ])

        updateContent()
    }

    private func show(animated: Bool) {
        guard animated else { return }
        alpha = 0
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }

    private func updateContent() {
        activityIndicator.isHidden = mode != .indeterminate
        customViewContainer.isHidden = mode != .customView || customView == nil
        label.isHidden = label.text?.isEmpty ?? true
    }
}

final class HUDLabel: UILabel {
    var onTextChange: (() -> Void)?

    override var text: String? {
        didSet { onTextChange?() }
    }
}
