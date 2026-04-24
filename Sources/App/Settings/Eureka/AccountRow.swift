import Eureka
import Foundation
import HAKit
import Shared

enum AccountRowValue: Equatable, CustomStringConvertible {
    case server(Server)
    case add
    case all

    var description: String {
        switch self {
        case let .server(server): return String(describing: server.identifier)
        case .add: return "add"
        case .all: return "all"
        }
    }

    var server: Server? {
        switch self {
        case let .server(server): return server
        case .add: return nil
        case .all: return nil
        }
    }

    var placeholderTitle: String? {
        switch self {
        case .server: return nil
        case .add: return L10n.Settings.ConnectionSection.addServer
        case .all: return L10n.Settings.ConnectionSection.allServers
        }
    }

    func placeholderImage(traitCollection: UITraitCollection) -> UIImage? {
        switch self {
        case .server: return nil
        case .add: return AccountInitialsImage.addImage(traitCollection: traitCollection)
        case .all: return AccountInitialsImage.allImage(traitCollection: traitCollection)
        }
    }
}

class AccountCell: Cell<AccountRowValue>, CellType {
    private var accountRow: HomeAssistantAccountRow? { row as? HomeAssistantAccountRow }

    override func setup() {
        super.setup()

        imageView?.layer.masksToBounds = true

        textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)

        selectionStyle = .default
    }

    override func update() {
        super.update()

        if case let .server(server) = accountRow?.value {
            let userName = accountRow?.cachedUserName
            let locationName = server.info.name
            let size = AccountInitialsImage.defaultSize
            let showHACloudBadge = server.info.connection.canUseCloud

            if let imageView {
                if let image = accountRow?.cachedImage {
                    UIView.transition(
                        with: imageView,
                        duration: imageView.image != nil ? 0.25 : 0,
                        options: [.transitionCrossDissolve]
                    ) {
                        // scaled down because the cell sizes to fit too much
                        imageView.image = image.scaledToSize(size)
                    } completion: { _ in
                    }
                } else {
                    imageView.image = AccountInitialsImage.image(for: userName ?? "?")
                }

                // Cropping image instead of image view to avoid cropping HA cloud badge too
                imageView.image = imageView.image?.croppedToCircle()

                if showHACloudBadge {
                    let badgeImage = Asset.haCloudLogo.image
                    let haCloudBadge = UIImageView(image: badgeImage)
                    imageView.addSubview(haCloudBadge)
                    imageView.contentMode = .scaleAspectFit
                    haCloudBadge.translatesAutoresizingMaskIntoConstraints = false
                    haCloudBadge.clipsToBounds = false
                    NSLayoutConstraint.activate([
                        haCloudBadge.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
                        haCloudBadge.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
                    ])
                }
            }

            accessoryType = .disclosureIndicator
            textLabel?.text = locationName
            // default value ensures height even when username isn't loaded yet
            detailTextLabel?.text = userName ?? " "
        } else {
            accessoryType = .none
            textLabel?.text = accountRow?.value?.placeholderTitle
            detailTextLabel?.text = nil
            imageView?.image = accountRow?.value?.placeholderImage(traitCollection: traitCollection)
        }

        detailTextLabel?.textColor = .secondaryLabel
    }
}

final class HomeAssistantAccountRow: Row<AccountCell>, RowType {
    var presentationMode: PresentationMode<UIViewController>?

    override func customDidSelect() {
        super.customDidSelect()
        if !isDisabled {
            if let presentationMode {
                if let controller = presentationMode.makeController() {
                    presentationMode.present(controller, row: self, presentingController: cell.formViewController()!)
                } else {
                    presentationMode.present(nil, row: self, presentingController: cell.formViewController()!)
                }
            }
        }
    }

    required init(tag: String?) {
        super.init(tag: tag)
        self.cellStyle = .subtitle
    }

    deinit {
        currentUserRequest?.cancel()
        avatarRequest?.cancel()
    }

    fileprivate var cachedImage: UIImage?
    fileprivate var cachedUserName: String?
    private var currentUserRequest: HACancellable? {
        didSet {
            oldValue?.cancel()
        }
    }

    private var avatarRequest: HACancellable? {
        didSet {
            oldValue?.cancel()
        }
    }

    override var value: Cell.Value? {
        didSet {
            if value != oldValue {
                fetchAvatar()
            }
        }
    }

    private func fetchAvatar() {
        currentUserRequest = nil
        avatarRequest = nil

        guard let server = value?.server else {
            cachedImage = nil
            cachedUserName = nil
            updateCell()
            return
        }

        cachedImage = nil
        cachedUserName = nil
        updateCell()

        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available to fetch avatar")
            return
        }

        currentUserRequest = api.currentUser { [weak self] user in
            guard let self else { return }
            guard value?.server?.identifier == server.identifier else { return }

            cachedUserName = user?.name
            updateCell()

            guard let user else {
                return
            }

            avatarRequest = api.profilePicture(for: user) { [weak self] image in
                guard let self else { return }
                guard value?.server?.identifier == server.identifier else { return }

                cachedImage = image
                updateCell()
            }
        }
    }
}
