import Foundation
import HADesignSystem
import PromiseKit
import SFSafeSymbols
import Shared
import UIKit
import UserNotificationsUI

class NotificationErrorViewController: UIViewController, NotificationCategory {
    private let error: Error
    private let onRetry: (() -> Void)?

    private lazy var iconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemSymbol: .videoSlash))
        imageView.preferredSymbolConfiguration = .init(pointSize: 36, weight: .regular)
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Extensions.NotificationContent.ErrorState.title
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Extensions.NotificationContent.ErrorState.message
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var retryButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.Extensions.NotificationContent.ErrorState.retry
        configuration.image = UIImage(systemSymbol: .arrowClockwise)
        configuration.imagePadding = DesignSystem.Spaces.one
        configuration.cornerStyle = .capsule
        configuration.contentInsets = .init(
            top: DesignSystem.Spaces.oneAndMicro,
            leading: DesignSystem.Spaces.three,
            bottom: DesignSystem.Spaces.oneAndMicro,
            trailing: DesignSystem.Spaces.three
        )
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        return button
    }()

    private lazy var detailsButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = .secondaryLabel
        configuration.titleTextAttributesTransformer = .init { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .footnote)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(toggleDetails), for: .touchUpInside)
        return button
    }()

    private lazy var detailsLabel: UILabel = {
        let label = UILabel()
        label.text = error.localizedDescription
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            iconView,
            titleLabel,
            messageLabel,
            retryButton,
            detailsButton,
            detailsLabel,
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = DesignSystem.Spaces.one
        stack.setCustomSpacing(DesignSystem.Spaces.oneAndHalf, after: iconView)
        stack.setCustomSpacing(DesignSystem.Spaces.two, after: messageLabel)
        stack.setCustomSpacing(DesignSystem.Spaces.half, after: retryButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    required init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws {
        fatalError("not meant to be used in the list of potentials, just directly set")
    }

    init(error: Error, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        retryButton.isHidden = onRetry == nil
        updateDetailsButton()

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: DesignSystem.Spaces.three),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -DesignSystem.Spaces.three),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spaces.three),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spaces.three),
        ])
    }

    @objc private func retryTapped() {
        onRetry?()
    }

    @objc private func toggleDetails() {
        detailsLabel.isHidden.toggle()
        updateDetailsButton()
    }

    private func updateDetailsButton() {
        detailsButton.configuration?.title = detailsLabel.isHidden
            ? L10n.Extensions.NotificationContent.ErrorState.showDetails
            : L10n.Extensions.NotificationContent.ErrorState.hideDetails
    }

    func start() -> Promise<Void> {
        .value(())
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType { .none }
    var mediaPlayPauseButtonFrame: CGRect?
    var mediaPlayPauseButtonTintColor: UIColor?
    func mediaPlay() {}
    func mediaPause() {}
}

@available(iOS 17.0, *)
#Preview {
    NotificationErrorViewController(
        error: CameraViewController.CameraViewControllerError.accumulated([
            CameraStreamWebRTCViewController.WebRTCError.unavailable,
            CameraStreamHLSViewController.HLSError.noPath,
        ]),
        onRetry: {}
    )
}
