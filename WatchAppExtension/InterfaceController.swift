//
//  InterfaceController.swift
//  WatchApp Extension
//
//  Created by Robert Trencheny on 9/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import WatchKit
import Iconic
import EMTLoadingIndicator
import RealmSwift

class InterfaceController: WKInterfaceController {
    @IBOutlet weak var tableView: WKInterfaceTable!

    let allIcons = MaterialDesignIcons.allCases.prefix(5)
    let color = UIColor(red: 0.01, green: 0.66, blue: 0.96, alpha: 1.0)

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        print("ONE")

        Iconic.registerMaterialDesignIcons()

        self.setupTable()
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func setupTable() {
//        self.tableView.setNumberOfRows(allIcons.count, withRowType: "actionRowType")
//
//        for (i, icon) in allIcons.enumerated() {
//            if let row = self.tableView.rowController(at: i) as? ActionRowType {
//                print("Setup row \(i) with \(icon.name)")
//                row.indicator = EMTLoadingIndicator(interfaceController: self, interfaceImage: row.image,
//                                                    width: 40, height: 40, style: .dot)
//                row.icon = icon
//                row.image.setImage(row.icon.image(ofSize: CGSize(width: 32, height: 32), color: color))
//                row.image.setAlpha(1)
//                row.label.setText(icon.name)
//            }
//        }

//        let rows: [[Any]] = [
//            [MaterialDesignIcons.powerIcon, UIColor(red: 0.99, green: 0.18, blue: 0.29, alpha: 1.0), "All Lights Off"],
//            [MaterialDesignIcons.weatherNightIcon, UIColor(red: 0.50, green: 0.36, blue: 0.92, alpha: 1.0), "Late Evening"],
//            [MaterialDesignIcons.kettleIcon, UIColor(red: 0.40, green: 0.83, blue: 0.29, alpha: 1.0), "Kettle On"],
//            [MaterialDesignIcons.weatherSunnyIcon, UIColor(red: 1.00, green: 0.57, blue: 0.18, alpha: 1.0), "Morning Wakeup Hello World"]
//        ]
//
//        self.tableView.setNumberOfRows(rows.count, withRowType: "actionRowType")
//
//        for (i, config) in rows.enumerated() {
//            if let row = self.tableView.rowController(at: i) as? ActionRowType,
//                let icon = config[0] as? MaterialDesignIcons, let bgColor = config[1] as? UIColor,
//                let labelText = config[2] as? String {
//                print("Setup row \(i) with \(icon.name)")
//                row.group.setBackgroundColor(bgColor)
//                row.indicator = EMTLoadingIndicator(interfaceController: self, interfaceImage: row.image,
//                                                    width: 24, height: 24, style: .dot)
//                row.icon = icon
//                row.image.setImage(row.icon.image(ofSize: CGSize(width: 24, height: 24), color: .white))
//                row.image.setAlpha(1)
//                row.label.setText(labelText)
//            }
//        }

        let realm = Realm.live()

        let actions = realm.objects(Action.self).sorted(byKeyPath: "Position")

        self.tableView.setNumberOfRows(actions.count, withRowType: "actionRowType")

        for (i, action) in actions.enumerated() {
            if let row = self.tableView.rowController(at: i) as? ActionRowType {
                print("Setup row \(i) with action", action)
                row.group.setBackgroundColor(UIColor(hex: action.BackgroundColor))
                row.indicator = EMTLoadingIndicator(interfaceController: self, interfaceImage: row.image,
                                                    width: 24, height: 24, style: .dot)
                row.icon = MaterialDesignIcons.init(named: action.IconName)
                let iconColor = UIColor(hex: action.IconColor)
                row.image.setImage(row.icon.image(ofSize: CGSize(width: 24, height: 24), color: iconColor))
                row.image.setAlpha(1)
                row.label.setText(action.Text)
                row.label.setTextColor(UIColor(hex: action.TextColor))
            }
        }

    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        let selectedIcon = allIcons[rowIndex]

        print("Selected row at index", rowIndex, selectedIcon.name)

        print("Show icon!")

        if let row = self.tableView.rowController(at: rowIndex) as? ActionRowType {
            row.indicator?.prepareImagesForWait()
            row.indicator?.showWait()

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                print("Hide!")
                row.image.stopAnimating()

                row.image.setImage(row.icon.image(ofSize: CGSize(width: 24, height: 24), color: .white))
            }
        }
    }
}
