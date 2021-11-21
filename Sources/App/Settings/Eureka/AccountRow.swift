import Eureka
import Foundation
import HAKit
import PromiseKit
import Shared

enum AccountRowValue: Equatable, CustomStringConvertible {
    case server(Server)
    case add
    case all

    var description: String {
        switch self {
        case .server(let server): return String(describing: server.identifier)
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
        case .all: return NSLocalizedString("All Servers", comment: "")
        }
    }

    var placeholderSubtitle: String? {
        switch self {
        case .server: return nil
        case .add: return "[todo]"
        case .all: return "[todo]"
        }
    }

    var placeholderImage: UIImage? {
        switch self {
        case .server: return nil
        case .add: return AccountInitialsImage.addImage()
        case .all: return AccountInitialsImage.allImage()
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

            if let imageView = imageView {
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

                imageView.layer.cornerRadius = ceil(size.height / 2.0)
            }

            accessoryType = .disclosureIndicator
            textLabel?.text = locationName
            // default value ensures height even when username isn't loaded yet
            detailTextLabel?.text = userName ?? " "
        } else {
            accessoryType = .none
            textLabel?.text = accountRow?.value?.placeholderTitle
            detailTextLabel?.text = accountRow?.value?.placeholderSubtitle
            imageView?.image = accountRow?.value?.placeholderImage
        }

        if #available(iOS 13, *) {
            detailTextLabel?.textColor = .secondaryLabel
        } else {
            detailTextLabel?.textColor = .darkGray
        }
    }
}

final class HomeAssistantAccountRow: Row<AccountCell>, RowType {
    var presentationMode: PresentationMode<UIViewController>?

    override func customDidSelect() {
        super.customDidSelect()
        if !isDisabled {
            if let presentationMode = presentationMode {
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
        accountSubscription?.cancel()
        avatarSubscription?.cancel()
    }

    fileprivate var cachedImage: UIImage?
    fileprivate var cachedUserName: String?
    private var accountSubscription: HACancellable? {
        didSet {
            oldValue?.cancel()
        }
    }

    private var avatarSubscription: HACancellable? {
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

    enum FetchAvatarError: Error, CancellableError {
        case missingPerson
        case missingURL
        case alreadySet
        case couldntDecode

        var isCancelled: Bool {
            if self == .alreadySet {
                return true
            } else {
                return false
            }
        }
    }

    private func fetchAvatar() {
        guard let server = value?.server else {
            cachedImage = nil
            cachedUserName = nil
            updateCell()
            return
        }

        let connection = Current.api(for: server).connection

        accountSubscription = connection.caches.user.subscribe { [weak self] _, user in
            guard let self = self else { return }
            Current.Log.verbose("got user from user \(user)")
            self.cachedUserName = user.name
            self.updateCell()

            var lastTask: URLSessionDataTask? {
                didSet {
                    oldValue?.cancel()
                    lastTask?.resume()
                }
            }

            self.avatarSubscription = connection.caches.states.subscribe { [weak self] _, states in
                firstly { () -> Guarantee<Set<HAEntity>> in
                    Guarantee.value(states.all)
                }.map { states throws -> HAEntity in
                    if let person = states.first(where: { $0.attributes["user_id"] as? String == user.id }) {
                        return person
                    } else {
                        throw FetchAvatarError.missingPerson
                    }
                }.map { entity -> String in
                    if let urlString = entity.attributes["entity_picture"] as? String {
                        return urlString
                    } else {
                        throw FetchAvatarError.missingURL
                    }
                }.map { path throws -> URL in
                    let url = server.info.connection.activeURL().appendingPathComponent(path)
                    if let lastTask = lastTask, lastTask.error == nil, lastTask.originalRequest?.url == url {
                        throw FetchAvatarError.alreadySet
                    }
                    return url
                }.then { url -> Promise<Data> in
                    Promise<Data> { seal in
                        lastTask = URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
                            seal.resolve(data, error)
                        })
                    }
                }.map { data throws -> UIImage in
                    if let image = UIImage(data: data) {
                        return image
                    } else {
                        throw FetchAvatarError.couldntDecode
                    }
                }.done { [weak self] image in
                    Current.Log.verbose("got image \(image.size)")
                    self?.cachedImage = image
                    self?.updateCell()
                }.cauterize()
            }
        }
    }
}
