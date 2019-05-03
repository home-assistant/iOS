//
//  SettingsViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/20/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Eureka
import Shared
import RealmSwift
import Lokalise
import ZIPFoundation
import UserNotifications

// swiftlint:disable:next type_body_length
class SettingsViewController: FormViewController {

    private var shakeCount = 0
    private var maxShakeCount = 3

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()
        self.becomeFirstResponder()

        let aboutButton = UIBarButtonItem(title: L10n.Settings.NavigationBar.AboutButton.title,
                                          style: .plain, target: self,
                                          action: #selector(SettingsViewController.openAbout(_:)))

        self.navigationItem.setLeftBarButton(aboutButton, animated: true)

        let closeSelector = #selector(OldSettingsViewController.closeSettings(_:))
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self,
                                         action: closeSelector)

        self.navigationItem.setRightBarButton(doneButton, animated: true)

        form +++ Section(L10n.Settings.StatusSection.header) {
            $0.tag = "status"
        }
        <<< LabelRow("locationName") {
            $0.title = L10n.Settings.StatusSection.LocationNameRow.title
            $0.value = L10n.Settings.StatusSection.LocationNameRow.placeholder
            if let locationName = prefs.string(forKey: "location_name") {
                $0.value = locationName
            }
        }
        <<< LabelRow("version") {
            $0.title = L10n.Settings.StatusSection.VersionRow.title
            $0.value = L10n.Settings.StatusSection.VersionRow.placeholder
            if let version = prefs.string(forKey: "version") {
                $0.value = version
            }
        }

        +++ Section(L10n.Settings.NavigationBar.title)
        <<< ButtonRow("generalSettings") {
            $0.title = L10n.Settings.GeneralSettingsButton.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "general"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        <<< ButtonRow {
            $0.title = L10n.Settings.ConnectionSection.header
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                return ConnectionSettingsViewController()
            }, onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        <<< ButtonRow("locationSettings") {
            $0.title = L10n.Settings.DetailsSection.LocationSettingsRow.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "location"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        <<< ButtonRow("notificationSettings") {
            $0.title = L10n.Settings.DetailsSection.NotificationSettingsRow.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "notifications"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        +++ Section(L10n.Settings.DetailsSection.Integrations.header)
        <<< ButtonRow {
            $0.tag = "actions"
            $0.title = L10n.SettingsDetails.Actions.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "actions"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        <<< ButtonRow {
            $0.tag = "watchSettings"
            $0.title = L10n.Settings.DetailsSection.WatchRow.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "watchSettings"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        <<< ButtonRow {
            $0.hidden = Condition(booleanLiteral: UIDevice.current.systemVersion == "12")
            $0.tag = "siriShortcuts"
            $0.title = L10n.Settings.DetailsSection.SiriShortcutsRow.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "siri"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        +++ ButtonRow("eventLog") {
            $0.title = L10n.Settings.EventLog.title
            let controllerProvider = ControllerProvider.storyBoard(storyboardId: "clientEventsList",
                                                                   storyboardName: "ClientEvents",
                                                                   bundle: Bundle.main)
            $0.presentationMode = .show(controllerProvider: controllerProvider, onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        +++ Section {
            $0.tag = "reset"
            // $0.hidden = Condition(booleanLiteral: !self.configured)
        }
        <<< ButtonRow("resetApp") {
                $0.title = L10n.Settings.ResetSection.ResetRow.title
            }.cellUpdate { cell, _ in
                cell.textLabel?.textColor = .red
            }.onCellSelection { cell, row in
                let alert = UIAlertController(title: L10n.Settings.ResetSection.ResetAlert.title,
                                              message: L10n.Settings.ResetSection.ResetAlert.message,
                                              preferredStyle: UIAlertController.Style.alert)

                alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))

                alert.addAction(UIAlertAction(title: L10n.Settings.ResetSection.ResetAlert.title,
                                              style: .destructive, handler: { (_) in
                                                row.hidden = true
                                                row.evaluateHidden()
                                                self.ResetApp()
                }))

                self.present(alert, animated: true, completion: nil)
                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
        }

        +++ ButtonRow {
            $0.title = L10n.Settings.Developer.ExportLogFiles.title
        }.onCellSelection { cell, _ in
            Current.Log.verbose("Logs directory is: \(Constants.LogsDirectory)")

            let fileManager = FileManager.default

            let fileName = DateFormatter(withFormat: "yyyy-MM-dd'T'HHmmssZ",
                                         locale: "en_US_POSIX").string(from: Date()) + "_logs.zip"

            Current.Log.debug("Exporting logs as filename \(fileName)")

            if let zipDest = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Constants.AppGroupID)?
                .appendingPathComponent(fileName, isDirectory: false) {

                _ = try? fileManager.removeItem(at: zipDest)

                guard let archive = Archive(url: zipDest, accessMode: .create) else {
                    fatalError("Unable to create ZIP archive!")
                }

                guard let backupURL = Realm.backup() else {
                    fatalError("Unable to backup Realm!")
                }

                do {
                    try archive.addEntry(with: backupURL.lastPathComponent,
                                         relativeTo: backupURL.deletingLastPathComponent())
                } catch {
                    Current.Log.error("Error adding Realm backup to archive!")
                }

                if let logFiles = try? fileManager.contentsOfDirectory(at: Constants.LogsDirectory,
                                                                       includingPropertiesForKeys: nil) {
                    for logFile in logFiles {
                        do {
                            try archive.addEntry(with: logFile.lastPathComponent,
                                                 relativeTo: logFile.deletingLastPathComponent())
                        } catch {
                            Current.Log.error("Error adding log \(logFile) to archive!")
                        }
                    }
                }

                let activityViewController = UIActivityViewController(activityItems: [zipDest],
                                                                      applicationActivities: nil)
                self.present(activityViewController, animated: true, completion: {})
                if let popOver = activityViewController.popoverPresentationController {
                    popOver.sourceView = cell
                }
            }
        }

        +++ Section(header: L10n.Settings.Developer.header, footer: L10n.Settings.Developer.footer) {
            $0.hidden = Condition(booleanLiteral: (Current.appConfiguration.rawValue > 1))
            $0.tag = "developerOptions"
        }

        <<< ButtonRow("onboardTest") {
            $0.title = "Onboard"
            $0.presentationMode = .presentModally(controllerProvider: .storyBoard(storyboardId: "navController",
                                                                                  storyboardName: "Onboarding",
                                                                                  bundle: Bundle.main), onDismiss: nil)
        }.cellUpdate { cell, _ in
            cell.textLabel?.textAlignment = .center
            cell.accessoryType = .none
            cell.editingAccessoryType = cell.accessoryType
            cell.textLabel?.textColor = cell.tintColor.withAlphaComponent(1.0)
        }

        <<< ButtonRow {
            $0.title = L10n.Settings.Developer.SyncWatchContext.title
        }.onCellSelection { cell, _ in
            if let syncError = HomeAssistantAPI.SyncWatchContext() {
                let alert = UIAlertController(title: L10n.errorLabel,
                                              message: syncError.localizedDescription,
                                              preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))

                self.present(alert, animated: true, completion: nil)
                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
            }
        }

        <<< ButtonRow {
            $0.title = L10n.Settings.Developer.CopyRealm.title
        }.onCellSelection { cell, _ in
            guard let backupURL = Realm.backup() else {
                fatalError("Unable to get Realm backup")
            }
            let containerRealmPath = Realm.Configuration.defaultConfiguration.fileURL!

            Current.Log.verbose("Would copy from \(backupURL) to \(containerRealmPath)")

            if FileManager.default.fileExists(atPath: containerRealmPath.path) {
                do {
                    _ = try FileManager.default.removeItem(at: containerRealmPath)
                } catch let error {
                    Current.Log.error("Error occurred, here are the details:\n \(error)")
                }
            }

            do {
                _ = try FileManager.default.copyItem(at: backupURL, to: containerRealmPath)
            } catch let error as NSError {
                // Catch fires here, with an NSError being thrown
                Current.Log.error("Error occurred, here are the details:\n \(error)")
            }

            let msg = L10n.Settings.Developer.CopyRealm.Alert.message(backupURL.path,
                                                                      containerRealmPath.path)

            let alert = UIAlertController(title: L10n.Settings.Developer.CopyRealm.Alert.title,
                                          message: msg,
                                          preferredStyle: UIAlertController.Style.alert)

            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))

            self.present(alert, animated: true, completion: nil)

            alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
        }

        <<< ButtonRow {
            $0.title = L10n.Settings.Developer.DebugStrings.title
        }.onCellSelection { cell, _ in
            prefs.set(!prefs.bool(forKey: "showTranslationKeys"), forKey: "showTranslationKeys")

            Lokalise.shared.localizationType = Current.appConfiguration.lokaliseEnv

            let alert = UIAlertController(title: L10n.okLabel, message: nil, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))

            self.present(alert, animated: true, completion: nil)

            alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
        }
        <<< ButtonRow {
            $0.title = L10n.Settings.Developer.CameraNotification.title
        }.onCellSelection { _, _ in
            self.showCameraContentExtension()
        }
        <<< ButtonRow {
            $0.title = L10n.Settings.Developer.MapNotification.title
        }.onCellSelection { _, _ in
            self.showMapContentExtension()
        }
    }

    @objc func openAbout(_ sender: UIButton) {
        let aboutView = AboutViewController()

        let navController = UINavigationController(rootViewController: aboutView)
        self.show(navController, sender: nil)
    }

    @objc func closeSettings(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    func ResetApp() {
        Current.Log.verbose("Resetting app!")
        resetStores()
        setDefaults()
        let bundleId = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: bundleId)
        UserDefaults.standard.synchronize()
        prefs.removePersistentDomain(forName: bundleId)
        prefs.synchronize()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            Current.Log.verbose("shake!")
            if shakeCount >= maxShakeCount {
                if let section = self.form.sectionBy(tag: "developerOptions") {
                    section.hidden = false
                    section.evaluateHidden()
                    self.tableView.reloadData()

                    let alert = UIAlertController(title: "You did it!",
                                                  message: "Developer functions unlocked",
                                                  preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
                                                  handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    alert.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
                }
                return
            }
            shakeCount += 1
        }
    }

    func showMapContentExtension() {
        let content = UNMutableNotificationContent()
        content.body = L10n.Settings.Developer.MapNotification.Notification.body
        content.sound = .default
        content.userInfo = ["homeassistant": ["latitude": "40.785091", "longitude": "-73.968285",
                                              "second_latitude": "40.758896", "second_longitude": "-73.985130"]]
        content.categoryIdentifier = "map"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let notificationRequest = UNNotificationRequest(identifier: "mapContentExtension", content: content,
                                                        trigger: trigger)
        UNUserNotificationCenter.current().add(notificationRequest)
    }

    func showCameraContentExtension() {
        let content = UNMutableNotificationContent()
        content.body = L10n.Settings.Developer.CameraNotification.Notification.body
        content.sound = .default
        content.userInfo = ["entity_id": "camera.vstarcamera_one"]
        content.categoryIdentifier = "camera"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let notificationRequest = UNNotificationRequest(identifier: "cameraContentExtension", content: content,
                                                        trigger: trigger)
        UNUserNotificationCenter.current().add(notificationRequest)
    }
}
