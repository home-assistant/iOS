import Lottie
import Shared
import UIKit

protocol PermissionViewChangeDelegate: AnyObject {
    func statusChanged(_ forPermission: PermissionType, _ toStatus: PermissionStatus)
}

@IBDesignable class PermissionLineItemView: UIView {
    let titleLabel = UILabel()
    let descriptionLabel = UILabel()
    var animationView = AnimationView()
    var button = PermissionButton()
    // var separatorView = UIView()

    var permission = PermissionType.location

    weak var delegate: PermissionViewChangeDelegate?

    @IBInspectable var permissionInt: Int = PermissionType.location.rawValue {
        didSet {
            guard let permission = PermissionType(rawValue: permissionInt) else {
                fatalError("Invalid permission int \(permissionInt)")
            }

            self.permission = permission
            titleLabel.text = permission.title
            descriptionLabel.text = permission.description
            animationView.animation = permission.animation
            commonInit()
        }
    }

    init(permission: PermissionType) {
        self.permission = permission
        super.init(frame: .zero)

        commonInit()
    }

    override required init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        commonInit()
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

    private func commonInit() {
        animationView.contentMode = .scaleAspectFill
        animationView.loopMode = .loop
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.play()

        backgroundColor = .clear

        addSubview(animationView)

        titleLabel.numberOfLines = 1
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        addSubview(titleLabel)

        descriptionLabel.numberOfLines = 3
        descriptionLabel.textColor = .white
        descriptionLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        addSubview(descriptionLabel)

        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)

        button.style = permission.isAuthorized ? .allowed : .default
        addSubview(button)

        // self.separatorView.backgroundColor = .white
        // self.addSubview(self.separatorView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        frame = CGRect(origin: frame.origin, size: CGSize(width: frame.width, height: 120))

        animationView.frame = CGRect(x: 0, y: 0, width: 75, height: 75)
        animationView.center.y = frame.height / 2

        button.sizeToFit()
        button.frame.origin.x = frame.width - button.frame.width
        button.center.y = frame.height / 2

        let titleInset: CGFloat = 15
        let titlesWidth: CGFloat = button.frame.origin
            .x - (animationView.frame.origin.x + animationView.frame.width) - titleInset * 2

        titleLabel.frame = CGRect(x: 0, y: 8, width: titlesWidth, height: 0)
        titleLabel.sizeToFit()
        titleLabel.frame = CGRect(
            origin: titleLabel.frame.origin,
            size: CGSize(width: titlesWidth, height: titleLabel.frame.height)
        )
        titleLabel.frame.origin.x = (animationView.frame.origin.x + animationView.frame.width) + titleInset

        descriptionLabel.frame = CGRect(x: titleLabel.frame.origin.x + titleInset, y: 0, width: titlesWidth, height: 0)
        descriptionLabel.sizeToFit()
        descriptionLabel.frame = CGRect(
            origin: descriptionLabel.frame.origin,
            size: CGSize(width: titlesWidth, height: descriptionLabel.frame.height)
        )
        descriptionLabel.frame.origin.x = animationView.frame.origin.x + animationView.frame.width + titleInset

        let allHeight = titleLabel.frame.height + 2 + descriptionLabel.frame.height
        titleLabel.frame.origin.y = (frame.height - allHeight) / 2
        descriptionLabel.frame.origin.y = titleLabel.frame.origin.y + titleLabel.frame.height + 2

        // self.separatorView.frame = CGRect(x: self.descriptionLabel.frame.origin.x, y: self.frame.height - 0.7, width: self.button.frame.origin.x + self.button.frame.width - self.descriptionLabel.frame.origin.x, height: 0.7)
        // self.separatorView.layer.cornerRadius = self.separatorView.frame.height / 2
    }
}
