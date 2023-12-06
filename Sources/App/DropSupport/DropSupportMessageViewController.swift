import Shared
import UIKit

class DropSupportMessageViewController: UIViewController {
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(asset: Asset.SharedAssets.logo)
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.text = L10n.Announcement.DropSupport.title
        label.font = UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.text = L10n.Announcement.DropSupport.subtitle
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }()

    private let linkButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.Announcement.DropSupport.buttonReadMore, for: .normal)
        button.addTarget(self, action: #selector(linkButtonTapped), for: .touchUpInside)
        button.layer.cornerRadius = HACornerRadius.standard
        button.layer.borderColor = UIColor(asset: Asset.Colors.haPrimary)?.cgColor
        button.layer.borderWidth = 1
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.tintColor =  UIColor(asset: Asset.Colors.haPrimary)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        if #available(iOS 13.0, *) {
            let icon = UIImage(systemName: "arrow.up.right.square")
            button.setImage(icon, for: .normal)
        }
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()

    private let button: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(L10n.Announcement.DropSupport.button, for: .normal)
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        button.backgroundColor = UIColor(asset: Asset.Colors.haPrimary)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.layer.cornerRadius = HACornerRadius.standard
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize)
        if #available(iOS 13.0, *) {
            button.tintColor = .systemBackground
        } else {
            button.tintColor = .white
        }
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.distribution = .fillProportionally
        stackView.translatesAutoresizingMaskIntoConstraints = false

        stackView.addArrangedSubview(imageView)

        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        stackView.addArrangedSubview(titleLabel)

        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        stackView.addArrangedSubview(subtitleLabel)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)
        stackView.addArrangedSubview(linkButton)

        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: button.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 64),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

            imageView.heightAnchor.constraint(equalToConstant: 100),
            imageView.widthAnchor.constraint(equalToConstant: 100),

            button.topAnchor.constraint(greaterThanOrEqualTo: scrollView.bottomAnchor, constant: 16),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            button.heightAnchor.constraint(equalToConstant: 50),
            linkButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        view.layoutIfNeeded()
    }

    @objc private func buttonTapped() {
        dismiss(animated: true)
    }

    @objc private func linkButtonTapped() {
        guard let url = URL(string: "https://www.home-assistant.io/blog/") else { return }
        UIApplication.shared.open(url)
    }
}
