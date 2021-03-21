import Eureka
import Foundation
import HAKit
import PromiseKit
import Shared

class AccountCell: Cell<HomeAssistantAccountRowInfo>, CellType {
    private var accountRow: HomeAssistantAccountRow? { row as? HomeAssistantAccountRow }

    override func setup() {
        super.setup()

        imageView?.layer.masksToBounds = true

        textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)

        selectionStyle = .default
        accessoryType = .disclosureIndicator
    }

    override func update() {
        super.update()

        let userName = accountRow?.cachedUserName
        let locationName = accountRow?.value?.locationName

        let height = min(64, UIFont.preferredFont(forTextStyle: .body).lineHeight * 2.0)
        let size = CGSize(width: height, height: height)

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
                imageView.image = AccountInitialsImage
                    .image(
                        for: userName ?? "?",
                        size: CGSize(width: height, height: height)
                    )
            }

            imageView.layer.cornerRadius = ceil(height / 2.0)
        }

        textLabel?.text = locationName
        // default value ensures height even when username isn't loaded yet
        detailTextLabel?.text = userName ?? " "

        if #available(iOS 13, *) {
            detailTextLabel?.textColor = .secondaryLabel
        } else {
            detailTextLabel?.textColor = .darkGray
        }
    }
}

struct HomeAssistantAccountRowInfo: Equatable {
    var connection: HAConnection
    var locationName: String?

    static func == (lhs: HomeAssistantAccountRowInfo, rhs: HomeAssistantAccountRowInfo) -> Bool {
        lhs.connection === rhs.connection &&
            lhs.locationName == rhs.locationName
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

    fileprivate var cachedImage: UIImage?
    fileprivate var cachedUserName: String?

    override var value: Cell.Value? {
        didSet {
            if value != oldValue {
                fetchAvatar()
            }
        }
    }

    private func fetchAvatar() {
        guard let connection = value?.connection else {
            cachedImage = nil
            cachedUserName = nil
            updateCell()
            return
        }

        firstly { () -> Promise<(HAResponseCurrentUser, [HAEntity])> in
            let currentUser = connection.send(.currentUser()).promise
            let states = connection.caches.states.once().promise.map { Array($0.all) }

            return when(fulfilled: currentUser, states)
        }.get { [self] user, states in
            Current.Log.verbose("got user from user \(user)")
            cachedUserName = user.name
            updateCell()
        }.compactMap { user, states in
            states.first(where: { $0.attributes["user_id"] as? String == user.id })
        }.compactMap { entity in
            entity.attributes["entity_picture"] as? String
        }.compactMap { path in
            Current.settingsStore.connectionInfo?.activeURL.appendingPathComponent(path)
        }.then { url in
            URLSession.shared.dataTask(.promise, with: url)
        }.compactMap { response in
            UIImage(data: response.data)
        }.done { [self] image in
            Current.Log.verbose("got image \(image.size)")
            cachedImage = image
            updateCell()
        }.catch { error in
            Current.Log.error("failed to grab thumbnail: \(error)")
        }
    }
}
