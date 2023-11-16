import UIKit

protocol BiometricsAuthenticationViewControllerDelegate: AnyObject {
    func didTapUnlock()
}

final class BiometricsAuthenticationViewController: UIViewController {
    private let homeAssistantLogo: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "launchScreen-logo")
        imageView.frame = CGRect(x: 0, y: 0, width: 256, height: 256)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let unlockButton: UIView = {
        let containerView = UIView()
        let button = UIButton()
        button.setTitle(L10n.SettingsDetails.General.Security.unlockButton, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)

        containerView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
        ])
        containerView.backgroundColor = .homeAssistant
        containerView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        containerView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        button.isUserInteractionEnabled = false
        containerView.isUserInteractionEnabled = true
        return containerView
    }()

    weak var delegate: BiometricsAuthenticationViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    @objc private func didTapUnlock() {
        delegate?.didTapUnlock()
    }

    public func updateUnlockButtonVisibility(visible: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.unlockButton.isHidden = !visible
        }
    }

    private func setupUI() {
        if #available(iOSApplicationExtension 13.0, *) {
            view.backgroundColor = .systemBackground
        }

        let stackView = UIStackView(arrangedSubviews: [
            homeAssistantLogo,
            unlockButton,
        ])

        stackView.alignment = .center
        stackView.contentMode = .scaleToFill
        stackView.spacing = 32
        stackView.axis = .vertical
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        view.layoutIfNeeded()
        unlockButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapUnlock)))
        unlockButton.layer.cornerRadius = min(unlockButton.bounds.width, unlockButton.bounds.height) / 2

        #if targetEnvironment(macCatalyst)
        unlockButton.isHidden = false
        #else
        unlockButton.isHidden = true
        #endif
    }
}
