//
//  NotificationSettingsViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 5/8/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import Shared
import Realm

class NotificationSettingsViewController: FormViewController {

    var doneButton: Bool = false

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.doneButton {
            self.navigationItem.rightBarButtonItem = nil
            self.doneButton = false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        if doneButton {
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self,
                                             action: #selector(self.closeSettingsDetailView(_:)))
            self.navigationItem.setRightBarButton(doneButton, animated: true)
        }

        self.title = L10n.SettingsDetails.Notifications.title

        self.form
            +++ SwitchRow("confirmBeforeOpeningUrl") {
                $0.title = L10n.SettingsDetails.Notifications.PromptToOpenUrls.title
                $0.value = prefs.bool(forKey: "confirmBeforeOpeningUrl")
            }.onChange { row in
                prefs.setValue(row.value, forKey: "confirmBeforeOpeningUrl")
                prefs.synchronize()
            }
            +++ Section(header: L10n.SettingsDetails.Notifications.PushIdSection.header,
                        footer: L10n.SettingsDetails.Notifications.PushIdSection.footer)
            <<< TextAreaRow {
                $0.tag = "pushID"
                $0.placeholder = L10n.SettingsDetails.Notifications.PushIdSection.placeholder
                if let pushID = Current.settingsStore.pushID {
                    $0.value = pushID
                } else {
                    $0.value = L10n.SettingsDetails.Notifications.PushIdSection.notRegistered
                }
                $0.disabled = true
                $0.textAreaHeight = TextAreaHeight.dynamic(initialTextViewHeight: 40)
            }.cellSetup { cell, _ in
                cell.textView.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                          action: #selector(self.tapPushID(_:))))
            }

        let categories = Current.realm().objects(NotificationCategory.self).sorted(byKeyPath: "Identifier")

        let mvOpts: MultivaluedOptions = [.Insert, .Delete, .Reorder]
        let header = L10n.SettingsDetails.Notifications.Categories.header

        self.form
            +++ MultivaluedSection(multivaluedOptions: mvOpts, header: header, footer: "") { section in
                section.tag = "notification_categories"
                section.multivaluedRowToInsertAt = { index in
                    return self.getNotificationCategoryRow(nil)
                }
                section.addButtonProvider = { section in
                    return ButtonRow {
                        $0.title = L10n.addButtonLabel
                        $0.cellStyle = .value1
                        }.cellUpdate { cell, _ in
                            cell.textLabel?.textAlignment = .left
                    }
                }

                for category in categories {
                    section <<< getNotificationCategoryRow(category)
                }
            }

            +++ ButtonRow {
                $0.title = L10n.SettingsDetails.Notifications.ImportLegacySettings.Button.title
            }.onCellSelection { cell, _ in
                _ = HomeAssistantAPI.authenticatedAPI()?.MigratePushSettingsToLocal().done { cats in
                    let title = L10n.SettingsDetails.Notifications.ImportLegacySettings.Alert.title
                    let message = L10n.SettingsDetails.Notifications.ImportLegacySettings.Alert.message
                    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)

                    alert.popoverPresentationController?.sourceView = cell.contentView

                    let rows = cats.map { self.getNotificationCategoryRow($0) }
                    var section = self.form.sectionBy(tag: "notification_categories")
                    section?.insert(contentsOf: rows, at: 0)
                }
            }

            +++ ButtonRow {
                $0.title = L10n.SettingsDetails.Notifications.Sounds.title
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    return NotificationSoundsViewController()
                }, onDismiss: nil)
            }

            +++ ButtonRow {
                $0.title = L10n.SettingsDetails.Notifications.BadgeSection.Button.title
            }.onCellSelection { cell, _ in
                UIApplication.shared.applicationIconBadgeNumber = 0
                let title = L10n.SettingsDetails.Notifications.BadgeSection.ResetAlert.title
                let message = L10n.SettingsDetails.Notifications.BadgeSection.ResetAlert.message
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
            }

            +++ Section(header: L10n.SettingsDetails.Location.Notifications.header, footer: "")
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.Enter.title
                $0.value = prefs.bool(forKey: "enterNotifications")
            }.onChange({ (row) in
                if let val = row.value {
                    prefs.set(val, forKey: "enterNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.Exit.title
                $0.value = prefs.bool(forKey: "exitNotifications")
            }.onChange({ (row) in
                if let val = row.value {
                    prefs.set(val, forKey: "exitNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.BeaconEnter.title
                $0.value = prefs.bool(forKey: "beaconEnterNotifications")
            }.onChange({ (row) in
                if let val = row.value {
                    prefs.set(val, forKey: "beaconEnterNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.BeaconExit.title
                $0.value = prefs.bool(forKey: "beaconExitNotifications")
            }.onChange({ (row) in
                if let val = row.value {
                    prefs.set(val, forKey: "beaconExitNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.LocationChange.title
                $0.value = prefs.bool(forKey: "significantLocationChangeNotifications")
            }.onChange({ (row) in
                if let val = row.value {
                    prefs.set(val, forKey: "significantLocationChangeNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.BackgroundFetch.title
                $0.value = prefs.bool(forKey: "backgroundFetchLocationChangeNotifications")
            }.onChange({ (row) in
                if let val = row.value {
                    prefs.set(val, forKey: "backgroundFetchLocationChangeNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.PushNotification.title
                $0.value = prefs.bool(forKey: "pushLocationRequestNotifications")
            }.onChange({ (row) in
                if let val = row.value {
                    prefs.set(val, forKey: "pushLocationRequestNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.UrlScheme.title
                $0.value = prefs.bool(forKey: "urlSchemeLocationRequestNotifications")
            }.onChange({ (row) in
                if let val = row.value {
                    prefs.set(val, forKey: "urlSchemeLocationRequestNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.XCallbackUrl.title
                $0.value = prefs.bool(forKey: "xCallbackURLLocationRequestNotifications")
            }.onChange({ (row) in
                if let val = row.value {
                    prefs.set(val, forKey: "xCallbackURLLocationRequestNotifications")
                }
            })
    }

    @objc func closeSettingsDetailView(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    func getNotificationCategoryRow(_ category: NotificationCategory?) ->
        ButtonRowWithPresent<NotificationCategoryConfigurator> {
            var identifier = "new_category_"+UUID().uuidString
            var title = L10n.SettingsDetails.Notifications.NewCategory.title

            if let category = category {
                identifier = category.Identifier
                title = category.Name
            }

            return ButtonRowWithPresent<NotificationCategoryConfigurator> {
                $0.tag = identifier
                $0.title = title
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    return NotificationCategoryConfigurator(category: category)
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)

                    if let vc = vc as? NotificationCategoryConfigurator {
                        if vc.shouldSave == false {
                            Current.Log.verbose("Not saving category to DB and returning early!")
                            return
                        }

                        vc.row.title = vc.category.Name
                        vc.row.updateCell()

                        Current.Log.verbose("Saving category! \(vc.category)")

                        let realm = Current.realm()

                        // swiftlint:disable:next force_try
                        try! realm.write {
                            realm.add(vc.category, update: true)
                        }
                    }

                    HomeAssistantAPI.ProvideNotificationCategoriesToSystem()
                })
            }
    }

    @objc func tapPushID(_ sender: Any) {
        if let row = self.form.rowBy(tag: "pushID") as? TextAreaRow, let rowValue = row.value {
            let activityViewController = UIActivityViewController(activityItems: [rowValue],
                                                                  applicationActivities: nil)
            self.present(activityViewController, animated: true, completion: {})
            activityViewController.popoverPresentationController?.sourceView = self.view
        }
    }

    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at indexes: [IndexPath]) {
        super.rowsHaveBeenRemoved(rows, at: indexes)

        let deletedIDs = rows.compactMap { $0.tag }

        if deletedIDs.count == 0 { return }

        Current.Log.verbose("Rows removed \(rows), \(deletedIDs)")

        let realm = Current.realm()

        if (rows.first as? ButtonRowWithPresent<NotificationCategoryConfigurator>) != nil {
            // swiftlint:disable:next force_try
            try! realm.write {
                realm.delete(realm.objects(NotificationCategory.self).filter("Identifier IN %@", deletedIDs))
            }
        }
    }
}
