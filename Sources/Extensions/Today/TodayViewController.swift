//
//  TodayViewController.swift
//  TodayWidget
//
//  Created by Robert Trencheny on 10/8/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import UIKit
import NotificationCenter
import Shared
import RealmSwift
import UIColor_Hex_Swift
import PromiseKit

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
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = Self.sectionInsets
        layout.minimumInteritemSpacing = 8.0
        layout.minimumLineSpacing = 8.0

        self.actions = realm.objects(Action.self).sorted(byKeyPath: "Position")

        super.init(collectionViewLayout: layout)
    }

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let tokenInfo = Current.settingsStore.tokenInfo {
            Current.tokenManager = TokenManager(tokenInfo: tokenInfo)
        }
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
                return Self.sectionInsets.top  + flowLayout.minimumLineSpacing
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
        self.preferredContentSize = preferred
    }

    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        updatePreferredContentSize()
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return actions.count
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let action = self.actions[indexPath.row]

        let cellID = "actionCell"
        // swiftlint:disable:next force_cast
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath) as! ActionButtonCell

        cell.setup(action)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let sectionWidth = collectionView.bounds.inset(by: Self.sectionInsets).width
        let paddingWidth = flowLayout.minimumInteritemSpacing * (CGFloat(Self.itemsPerRow) - 1.0)
        let itemWidth = (sectionWidth - paddingWidth)/CGFloat(Self.itemsPerRow)

        return CGSize(width: itemWidth, height: Self.heightPerRow)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()

        guard let cell = collectionView.cellForItem(at: indexPath) as? ActionButtonCell else { return }

        cell.imageView.showActivityIndicator()

        let action = self.actions[indexPath.row]

        Current.api.then { api in
            api.HandleAction(actionID: action.ID, source: .Widget)
        }.done { _ in
            feedbackGenerator.notificationOccurred(.success)
        }.ensure {
            cell.imageView.hideActivityIndicator()
        }.catch { err -> Void in
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

        self.layer.cornerRadius = 5.0

        self.contentView.layer.cornerRadius = 2.0
        self.contentView.layer.borderWidth = 1.0
        self.contentView.layer.borderColor = UIColor.clear.cgColor
        self.contentView.layer.masksToBounds = true

        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 2.0)
        self.layer.shadowRadius = 2.0
        self.layer.shadowOpacity = 0.5
        self.layer.masksToBounds = false
        self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds,
                                             cornerRadius: self.contentView.layer.cornerRadius).cgPath

        let centerY = (self.frame.size.height / 2) - 50

        self.title = UILabel(frame: CGRect(x: 60, y: centerY, width: 200, height: 100))

        self.title.textAlignment = .natural
        self.title.clipsToBounds = true
        self.title.numberOfLines = 1
        self.title.font = self.title.font.withSize(UIFont.smallSystemFontSize)

        self.contentView.addSubview(self.title)
        self.contentView.addSubview(self.imageView)
    }

    public func setup(_ action: Action) {
        DispatchQueue.main.async {
            self.backgroundColor = UIColor(hex: action.BackgroundColor)

            let icon = MaterialDesignIcons.init(named: action.IconName)
            self.imageView.image = icon.image(ofSize: self.imageView.bounds.size,
                                              color: UIColor(hex: action.IconColor))
            self.title.text = action.Text
            self.title.textColor = UIColor(hex: action.TextColor)
        }
    }
}
