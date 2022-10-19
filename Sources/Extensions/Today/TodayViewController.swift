import NotificationCenter
import PromiseKit
import RealmSwift
import Shared
import UIColor_Hex_Swift
import UIKit

class TodayViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, NCWidgetProviding {
    static let sectionInsets = UIEdgeInsets(top: 4, left: 12, bottom: 12, right: 12)
    static let itemsPerRow: Int = 2
    static let compactRowCount: Int = 2
    static let heightPerRow: CGFloat = 44

    let realm = Current.realm()
    let actions: Results<Action>
    private var actionsObservationTokens: [NotificationToken] = []

    private var flowLayout: UICollectionViewFlowLayout {
        // swiftlint:disable:next force_cast
        collectionViewLayout as! UICollectionViewFlowLayout
    }

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = Self.sectionInsets
        layout.minimumInteritemSpacing = 8.0
        layout.minimumLineSpacing = 8.0

        self.actions = realm.objects(Action.self).sorted(byKeyPath: "Position")

        super.init(collectionViewLayout: layout)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        MaterialDesignIcons.register()
        collectionView.register(ActionButtonCell.self, forCellWithReuseIdentifier: "actionCell")
        collectionView.backgroundColor = .clear
        updatePreferredContentSize()

        actionsObservationTokens.append(actions.observe { [weak self] _ in
            self?.updatePreferredContentSize()
        })
    }

    func updatePreferredContentSize() {
        let displayMode: NCWidgetDisplayMode = extensionContext?.widgetActiveDisplayMode ?? .compact

        let fullyVisibleNumberOfRows: Int = {
            let (quotient, remainder) = actions.count.quotientAndRemainder(dividingBy: Self.itemsPerRow)
            return quotient + (remainder > 0 ? 1 : 0)
        }()

        let numberOfRows: Int = {
            switch displayMode {
            case .compact:
                return Self.compactRowCount
            case .expanded:
                return fullyVisibleNumberOfRows
            @unknown default:
                return fullyVisibleNumberOfRows
            }
        }()

        let rowHeights = CGFloat(numberOfRows) * Self.heightPerRow
        let spacingHeights = CGFloat(numberOfRows - 1) * flowLayout.minimumLineSpacing
        let insetHeights: CGFloat = {
            if numberOfRows < fullyVisibleNumberOfRows {
                return Self.sectionInsets.top + flowLayout.minimumLineSpacing
            } else {
                return Self.sectionInsets.top + Self.sectionInsets.bottom
            }
        }()

        let preferred = CGSize(
            width: 0,
            height: rowHeights + spacingHeights + insetHeights
        )

        if fullyVisibleNumberOfRows > Self.compactRowCount {
            extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        } else {
            extensionContext?.widgetLargestAvailableDisplayMode = .compact
        }

        let maximumHeight = extensionContext?.widgetMaximumSize(for: displayMode).height ?? 0
        Current.Log.info("content height \(preferred.height) for \(displayMode.rawValue) with max \(maximumHeight)")
        preferredContentSize = preferred
    }

    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        updatePreferredContentSize()
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        actions.count
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let action = actions[indexPath.row]

        let cellID = "actionCell"
        // swiftlint:disable:next force_cast
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath) as! ActionButtonCell

        cell.setup(action)

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let sectionWidth = collectionView.bounds.inset(by: Self.sectionInsets).width
        let paddingWidth = flowLayout.minimumInteritemSpacing * (CGFloat(Self.itemsPerRow) - 1.0)
        let itemWidth = (sectionWidth - paddingWidth) / CGFloat(Self.itemsPerRow)

        return CGSize(width: itemWidth, height: Self.heightPerRow)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()

        guard let cell = collectionView.cellForItem(at: indexPath) as? ActionButtonCell else { return }

        cell.imageView.showActivityIndicator()

        let action = actions[indexPath.row]

        firstly { () -> Promise<Void> in
            if let server = Current.servers.server(for: action) {
                return Current.api(for: server).HandleAction(actionID: action.ID, source: .Widget)
            } else {
                throw HomeAssistantAPI.APIError.notConfigured
            }
        }.done {
            feedbackGenerator.notificationOccurred(.success)
        }.ensure {
            cell.imageView.hideActivityIndicator()
        }.catch { err in
            Current.Log.error("Error during action event fire: \(err)")
            feedbackGenerator.notificationOccurred(.error)
        }
    }
}

class ActionButtonCell: UICollectionViewCell {
    var imageView = UIImageView(frame: CGRect(x: 15, y: 0, width: 44, height: 44))
    var title = UILabel(frame: CGRect(x: 60, y: 60, width: 200, height: 100))

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = 5.0

        contentView.layer.cornerRadius = 2.0
        contentView.layer.borderWidth = 1.0
        contentView.layer.borderColor = UIColor.clear.cgColor
        contentView.layer.masksToBounds = true

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2.0)
        layer.shadowRadius = 2.0
        layer.shadowOpacity = 0.5
        layer.masksToBounds = false
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: contentView.layer.cornerRadius
        ).cgPath

        let centerY = (frame.size.height / 2) - 50

        title = UILabel(frame: CGRect(x: 60, y: centerY, width: 200, height: 100))

        title.textAlignment = .natural
        title.clipsToBounds = true
        title.numberOfLines = 1
        title.font = title.font.withSize(UIFont.smallSystemFontSize)

        contentView.addSubview(title)
        contentView.addSubview(imageView)
    }

    public func setup(_ action: Action) {
        DispatchQueue.main.async {
            self.backgroundColor = UIColor(hex: action.BackgroundColor)

            let icon = MaterialDesignIcons(named: action.IconName)
            self.imageView.image = icon.image(
                ofSize: self.imageView.bounds.size,
                color: UIColor(hex: action.IconColor)
            )
            self.title.text = action.Text
            self.title.textColor = UIColor(hex: action.TextColor)
        }
    }
}
