import Foundation
import Eureka
import Shared
import PromiseKit

class AccountCell: Cell<HomeAssistantAccountRowInfo>, CellType {
    private var accountRow: HomeAssistantAccountRow? { return row as? HomeAssistantAccountRow }

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

        let userName = accountRow?.value?.user?.Name
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
                        for: userName,
                        size: CGSize(width: height, height: height)
                    )
            }

            imageView.layer.cornerRadius = ceil(height / 2.0)
        }

        textLabel?.text = locationName
        detailTextLabel?.text = userName

        if #available(iOS 13, *) {
            detailTextLabel?.textColor = .secondaryLabel
        } else {
            detailTextLabel?.textColor = .darkGray
        }
    }
}

struct HomeAssistantAccountRowInfo: Equatable {
    var user: AuthenticatedUser?
    var locationName: String?

    static func == (lhs: HomeAssistantAccountRowInfo, rhs: HomeAssistantAccountRowInfo) -> Bool {
        return lhs.user?.ID == rhs.user?.ID &&
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

    override var value: Cell.Value? {
        didSet {
            if value != oldValue {
                fetchAvatar()
            }
        }
    }

    private func fetchAvatar() {
        guard let user = value?.user else {
            cachedImage = nil
            return
        }

        Current.api.then {
            $0.GetStates()
        }.firstValue {
            $0.Attributes["user_id"] as? String == user.ID
        }.compactMap {
            $0.Attributes["entity_picture"] as? String
        }.compactMap {
            Current.settingsStore.connectionInfo?.activeURL.appendingPathComponent($0)
        }.then {
            URLSession.shared.dataTask(.promise, with: $0)
        }.compactMap {
            UIImage(data: $0.data)
        }.done { [self] image in
            Current.Log.verbose("got image \(image.size)")
            cachedImage = image
            updateCell()
        }.catch { error in
            Current.Log.error("failed to grab thumbnail: \(error)")
        }
    }
}
