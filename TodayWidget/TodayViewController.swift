//
//  TodayViewController.swift
//  TodayWidget
//
//  Created by Robert Trencheny on 10/8/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import UIKit
import NotificationCenter
import Iconic
import Shared
import RealmSwift
import UIColor_Hex_Swift
import PromiseKit

class TodayViewController: UIViewController, NCWidgetProviding,
                           UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {

    var collectionView: UICollectionView!
    let sectionInsets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    let itemsPerRow: CGFloat = 2

    let realm = Current.realm()

    var actions: Results<Action>?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        MaterialDesignIcons.register()

        if let tokenInfo = Current.settingsStore.tokenInfo,
            let connectionInfo = Current.settingsStore.connectionInfo {
            Current.tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: tokenInfo)
        }

        actions = realm.objects(Action.self).sorted(byKeyPath: "Position")

        if actions!.count > 2 {
            extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        }

        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = sectionInsets

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ActionButtonCell.self, forCellWithReuseIdentifier: "actionCell")
        collectionView.backgroundColor = .clear

        view.addSubview(collectionView)
    }

    override func viewWillLayoutSubviews() {
        let frame = view.frame
        collectionView?.frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width,
                                       height: frame.size.height)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.actions!.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let action = self.actions![indexPath.row]

        let cellID = "actionCell"
        // swiftlint:disable:next force_cast
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath) as! ActionButtonCell

        cell.setup(action)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow

        return CGSize(width: widthPerItem, height: 44)
    }

    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        // toggle height in case of more/less button event
        if activeDisplayMode == .compact {
            self.preferredContentSize = CGSize(width: 0, height: 110)
        } else {
            self.preferredContentSize = CGSize(width: 0, height: 220)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()

        guard let cell = collectionView.cellForItem(at: indexPath) as? ActionButtonCell else { return }

        cell.imageView.showActivityIndicator()

        let action = self.actions![indexPath.row]

        firstly {
            HomeAssistantAPI.authenticatedAPIPromise
        }.then { api in
            api.HandleAction(actionID: action.ID, actionName: action.Name, source: .Widget)
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
            self.imageView.image = icon.image(ofSize: CGSize(width: 22, height: 22),
                                              color: UIColor(hex: action.IconColor))
            self.title.text = action.Text
            self.title.textColor = UIColor(hex: action.TextColor)
        }
    }
}
