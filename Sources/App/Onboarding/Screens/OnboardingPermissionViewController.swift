import Shared
import UIKit

class OnboardingPermissionViewController: UIViewController, OnboardingViewController {
    let server: Server?
    let permission: PermissionType
    let factory: OnboardingPermissionViewControllerFactory.Type

    init(server: Server?, permission: PermissionType, factory: OnboardingPermissionViewControllerFactory.Type) {
        self.server = server
        self.permission = permission
        self.factory = factory
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var preferredBarAppearance: OnboardingBarAppearance { .hidden }

    private var headerImageView: UIImageView?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Current.style.onboardingBackground
        navigationItem.hidesBackButton = true

        let (_, stackView, equalSpacers) = UIView.contentStackView(in: view, scrolling: true)

        stackView.addArrangedSubview(with(UIImageView()) {
            headerImageView = $0
            $0.image = permission.enableIcon.image(ofSize: CGSize(width: 128, height: 128), color: .black)
                .withRenderingMode(.alwaysTemplate)
        })

        stackView.addArrangedSubview(with(UILabel()) {
            $0.text = permission.title
            Current.style.onboardingTitle($0)
        })

        let descriptionLabel = with(UILabel()) {
            $0.text = permission.enableDescription
            $0.font = .preferredFont(forTextStyle: .body)
            $0.textColor = Current.style.onboardingLabelSecondary
            $0.numberOfLines = 0
            $0.textAlignment = .center
        }
        stackView.addArrangedSubview(descriptionLabel)
        stackView.setCustomSpacing(stackView.spacing * 2.0, after: descriptionLabel)

        for bulletPoint in permission.enableBulletPoints {
            let view = with(UIStackView()) {
                $0.axis = .horizontal
                $0.alignment = .center
                $0.spacing = 16.0
                $0.directionalLayoutMargins = .init(top: 0, leading: 16, bottom: 0, trailing: 16)
                $0.isLayoutMarginsRelativeArrangement = true

                $0.addArrangedSubview(with(UIImageView()) {
                    $0.image = bulletPoint.0.image(ofSize: CGSize(width: 34, height: 34), color: .black)
                        .withRenderingMode(.alwaysTemplate)
                    $0.setContentCompressionResistancePriority(.required, for: .horizontal)
                    $0.setContentCompressionResistancePriority(.required, for: .vertical)
                    $0.setContentHuggingPriority(.required, for: .horizontal)
                    $0.setContentHuggingPriority(.required, for: .vertical)
                })
                $0.addArrangedSubview(with(UILabel()) {
                    $0.text = bulletPoint.1
                    $0.textColor = Current.style.onboardingLabel
                    $0.font = .preferredFont(forTextStyle: .body)
                    $0.numberOfLines = 0
                    $0.setContentHuggingPriority(.defaultLow, for: .horizontal)
                })
            }

            stackView.addArrangedSubview(view)

            switch traitCollection.userInterfaceIdiom {
            case .pad, .mac:
                view.widthAnchor.constraint(equalTo: stackView.readableContentGuide.widthAnchor)
                    .isActive = true
            default:
                view.widthAnchor.constraint(equalTo: stackView.layoutMarginsGuide.widthAnchor)
                    .isActive = true
            }
        }

        stackView.addArrangedSubview(equalSpacers.next())

        stackView.addArrangedSubview(with(UIButton(type: .custom)) {
            $0.setTitle(L10n.continueLabel, for: .normal)
            $0.addTarget(self, action: #selector(continueTapped(_:)), for: .touchUpInside)
            Current.style.onboardingButtonPrimary($0)
        })

        stackView.addArrangedSubview(with(UILabel()) {
            $0.font = .preferredFont(forTextStyle: .footnote)
            $0.textColor = Current.style.onboardingLabelSecondary
            $0.text = L10n.Onboarding.Permissions.changeLaterNote
            $0.numberOfLines = 0
            $0.textAlignment = .center
        })

        updateHiddenStates()
    }

    @objc private func continueTapped(_ sender: UIButton) {
        sender.isUserInteractionEnabled = false
        permission.request { [self] granted, _ in
            if permission == .location, granted, let currentSSID = Current.connectivity.currentWiFiSSID() {
                // update SSIDs if we have access to them, since we're gonna need it later
                server?.info.connection.internalSSIDs = [currentSSID]
            }

            sender.isUserInteractionEnabled = true
            show(factory.next(server: server), sender: self)
        }
    }

    private func updateHiddenStates() {
        let imageViewHidden = traitCollection.verticalSizeClass == .compact
        headerImageView?.isHidden = imageViewHidden
    }

    override func traitCollectionDidChange(_ traitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(traitCollection)
        updateHiddenStates()
    }
}
