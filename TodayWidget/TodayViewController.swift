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

        actions = realm.objects(Action.self).sorted(byKeyPath: "Position")

        if actions!.count > 2 {
            extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        }

        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = sectionInsets

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cellId")
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

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellId", for: indexPath)
        cell.backgroundColor = UIColor(hex: action.BackgroundColor)

        cell.layer.cornerRadius = 5.0

        cell.contentView.layer.cornerRadius = 2.0
        cell.contentView.layer.borderWidth = 1.0
        cell.contentView.layer.borderColor = UIColor.clear.cgColor
        cell.contentView.layer.masksToBounds = true

        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 2.0)
        cell.layer.shadowRadius = 2.0
        cell.layer.shadowOpacity = 0.5
        cell.layer.masksToBounds = false
        cell.layer.shadowPath = UIBezierPath(roundedRect: cell.bounds,
                                             cornerRadius: cell.contentView.layer.cornerRadius).cgPath

        let centerY = (cell.frame.size.height / 2) - 50

        let title = UILabel(frame: CGRect(x: 60, y: centerY, width: 200, height: 100))

        let size = CGRect(x: 15, y: 0, width: 44, height: 44)

        let imageview: UIImageView = UIImageView(frame: size)
        let icon = MaterialDesignIcons.init(named: action.IconName)
        let image: UIImage = icon.image(ofSize: CGSize(width: 22, height: 22), color: UIColor(hex: action.IconColor))
        imageview.image = image

        title.textAlignment = .natural
        title.clipsToBounds = true
        title.numberOfLines = 1
        title.font = title.font.withSize(UIFont.smallSystemFontSize)
        title.text = action.Text
        title.textColor = UIColor(hex: action.TextColor)

        cell.contentView.addSubview(title)
        cell.contentView.addSubview(imageview)

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
        print("User tapped on item \(indexPath.row)")
    }
}
