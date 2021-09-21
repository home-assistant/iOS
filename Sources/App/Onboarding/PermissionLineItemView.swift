import Lottie
import Shared
import UIKit

protocol PermissionViewChangeDelegate: AnyObject {
    func statusChanged(_ forPermission: PermissionType, _ toStatus: PermissionStatus)
}

@IBDesignable class PermissionLineItemView: UIView {
    let titleLabel = UILabel()
    let descriptionWrapper = UIView()
    let descriptionLabel = UILabel()
    let animationView = AnimationView()
    let button = PermissionButton()
    let titleStackView = UIStackView()

    var descriptionHeightConstraint: NSLayoutConstraint?

    var permission = PermissionType.location {
        didSet {
            updateContents()
        }
    }

    weak var delegate: PermissionViewChangeDelegate?

    @IBInspectable var permissionInt: Int = PermissionType.location.rawValue {
        didSet {
            guard let permission = PermissionType(rawValue: permissionInt) else {
                fatalError("Invalid permission int \(permissionInt)")
            }

            self.permission = permission
        }
    }

    convenience init(permission: PermissionType) {
        self.init(frame: .zero)
        self.permission = permission
        updateContents()
    }

    override required init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        // for visual alignment
        animationView.backgroundColor = .white
    }

    @objc private func updateContents() {
        titleLabel.text = permission.title
        descriptionLabel.text = permission.description
        animationView.animation = permission.animation
        button.style = permission.isAuthorized ? .allowed : .default
        animationView.play()
    }

    @objc func buttonTapped(_ sender: PermissionButton) {
        permission.request { success, newStatus in
            let newStyle: PermissionButton.Style = success ? .allowed : .default
            UIView.animate(withDuration: 0.2) {
                self.button.style = newStyle
            }
            self.delegate?.statusChanged(self.permission, newStatus)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsUpdateConstraints()
    }

    override func updateConstraints() {
        super.updateConstraints()

        let descConstraint: NSLayoutConstraint

        if let descriptionHeightConstraint = descriptionHeightConstraint {
            descConstraint = descriptionHeightConstraint
        } else {
            descConstraint = descriptionWrapper.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
            descriptionHeightConstraint = descConstraint
        }

        let lines: Int

        if traitCollection.verticalSizeClass == .compact {
            lines = 1
        } else {
            lines = 3
        }

        let desired = ceil(descriptionLabel.font.lineHeight * CGFloat(lines))

        if descConstraint.constant != desired {
            descConstraint.constant = desired
            descConstraint.isActive = true
        }
    }

    private func commonInit() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateContents),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        animationView.contentMode = .scaleAspectFill
        animationView.loopMode = .loop
        animationView.backgroundBehavior = .pauseAndRestore

        backgroundColor = .clear

        titleStackView.axis = .vertical
        titleStackView.alignment = .leading

        titleLabel.numberOfLines = 0
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleStackView.addArrangedSubview(titleLabel)

        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = .white
        descriptionLabel.font = .systemFont(ofSize: 13, weight: .regular)

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionWrapper.addSubview(descriptionLabel)
        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: descriptionWrapper.topAnchor),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: descriptionWrapper.bottomAnchor),
            descriptionLabel.leadingAnchor.constraint(equalTo: descriptionWrapper.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: descriptionWrapper.trailingAnchor),
        ])

        titleStackView.addArrangedSubview(descriptionWrapper)

        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)

        animationView.translatesAutoresizingMaskIntoConstraints = false
        titleStackView.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false

        addSubview(animationView)
        addSubview(titleStackView)
        addSubview(button)

        let margins = layoutMarginsGuide
        directionalLayoutMargins = .init(top: 8, leading: 0, bottom: 8, trailing: 0)

        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalToConstant: 75.0),
            button.widthAnchor.constraint(equalToConstant: 75.0),

            animationView.topAnchor.constraint(greaterThanOrEqualTo: margins.topAnchor),
            animationView.centerYAnchor.constraint(equalTo: margins.centerYAnchor),
            animationView.widthAnchor.constraint(equalTo: animationView.heightAnchor),
            animationView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            animationView.bottomAnchor.constraint(lessThanOrEqualTo: margins.bottomAnchor),

            titleStackView.topAnchor.constraint(greaterThanOrEqualTo: margins.topAnchor),
            titleStackView.leadingAnchor.constraint(equalTo: animationView.trailingAnchor),
            titleStackView.centerYAnchor.constraint(equalTo: margins.centerYAnchor),
            titleStackView.bottomAnchor.constraint(lessThanOrEqualTo: margins.bottomAnchor),

            button.leadingAnchor.constraint(greaterThanOrEqualTo: titleStackView.trailingAnchor, constant: 8),
            button.centerYAnchor.constraint(equalTo: margins.centerYAnchor),
            button.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ])
    }
}
