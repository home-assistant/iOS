import Eureka
import Foundation
import RealmSwift
import Shared
import UIKit
#if !targetEnvironment(macCatalyst)
import Lokalise
#endif
import FirebaseMessaging
import MBProgressHUD
import PromiseKit
import Sentry
import UserNotifications
import WebKit
import XCGLogger
import ZIPFoundation

class SettingsViewController: FormViewController {
    private var shakeCount = 0
    private var maxShakeCount = 3

    // swiftlint:disable:next cyclomatic_complexity
    override func viewDidLoad() {
        super.viewDidLoad()
        becomeFirstResponder()

        title = L10n.Settings.NavigationBar.title

        ButtonRow.defaultCellSetup = { cell, row in
            cell.accessibilityIdentifier = row.tag
            cell.accessibilityLabel = row.title
        }

        LabelRow.defaultCellSetup = { cell, row in
            cell.accessibilityIdentifier = row.tag
            cell.accessibilityLabel = row.title
        }

        if !Current.isCatalyst {
            // About is in the Application menu on Catalyst, and closing the button is direct

            let aboutButton = UIBarButtonItem(
                title: L10n.Settings.NavigationBar.AboutButton.title,
                style: .plain,
                target: self,
                action: #selector(SettingsViewController.openAbout(_:))
            )

            navigationItem.setLeftBarButton(aboutButton, animated: true)
        }

        if !Current.sceneManager.supportsMultipleScenes || !Current.isCatalyst {
            let closeSelector = #selector(SettingsViewController.closeSettings(_:))
            let doneButton = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: closeSelector
            )

            navigationItem.setRightBarButton(doneButton, animated: true)
        }

        form +++ HomeAssistantAccountRow {
            $0.value = .init(
                connection: Current.apiConnection,
                locationName: prefs.string(forKey: "location_name")
            )
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                ConnectionSettingsViewController()
            }, onDismiss: nil)
        }

        form +++ Section()
            <<< ButtonRow("generalSettings") {
                $0.title = L10n.Settings.GeneralSettingsButton.title
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    let view = SettingsDetailViewController()
                    view.detailGroup = "general"
                    return view
                }, onDismiss: nil)
            }

            <<< ButtonRow("locationSettings") {
                $0.title = L10n.Settings.DetailsSection.LocationSettingsRow.title
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    let view = SettingsDetailViewController()
                    view.detailGroup = "location"
                    return view
                }, onDismiss: nil)
            }

            <<< ButtonRow("notificationSettings") {
                $0.title = L10n.Settings.DetailsSection.NotificationSettingsRow.title
                $0.presentationMode = .show(controllerProvider: .callback {
                    NotificationSettingsViewController()
                }, onDismiss: nil)
            }

            <<< ButtonRow {
                $0.title = L10n.SettingsSensors.title
                $0.presentationMode = .show(controllerProvider: .callback {
                    SensorListViewController()
                }, onDismiss: nil)
            }

            +++ Section(L10n.Settings.DetailsSection.Integrations.header)
            <<< ButtonRow {
                $0.tag = "actions"
                $0.title = L10n.SettingsDetails.Actions.title
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    let view = SettingsDetailViewController()
                    view.detailGroup = "actions"
                    return view
                }, onDismiss: { _ in

                })
            }

            <<< ButtonRow {
                $0.tag = "watch"
                $0.hidden = .isCatalyst
                $0.title = L10n.Settings.DetailsSection.WatchRow.title
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    ComplicationListViewController()
                }, onDismiss: { _ in

                })
            }

            <<< ButtonRow {
                $0.title = L10n.Nfc.List.title

                if #available(iOS 13, *) {
                    $0.hidden = .isCatalyst
                    $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                        NFCListViewController()
                    }, onDismiss: nil)
                } else {
                    $0.hidden = true
                }
            }

            +++ ButtonRow("privacy") {
                $0.title = L10n.SettingsDetails.Privacy.title
                $0.presentationMode = .show(controllerProvider: .callback {
                    let view = SettingsDetailViewController()
                    view.detailGroup = "privacy"
                    return view
                }, onDismiss: nil)
            }

            +++ ButtonRow("eventLog") {
                $0.title = L10n.Settings.EventLog.title

                let scene = StoryboardScene.ClientEvents.self

                let controllerProvider = ControllerProvider.storyBoard(
                    storyboardId: scene.clientEventsList.identifier,
                    storyboardName: scene.storyboardName,
                    bundle: Bundle.main
                )

                $0.presentationMode = .show(controllerProvider: controllerProvider, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
                })
            }

            <<< ButtonRow {
                if Current.isCatalyst {
                    $0.title = L10n.Settings.Developer.ShowLogFiles.title
                } else {
                    $0.title = L10n.Settings.Developer.ExportLogFiles.title
                }
            }.onCellSelection { [weak self] cell, _ in
                Current.Log.verbose("Logs directory is: \(Constants.LogsDirectory)")

                guard !Current.isCatalyst else {
                    // on Catalyst we can just open the directory to get to Finder
                    UIApplication.shared.open(Constants.LogsDirectory, options: [:]) { success in
                        Current.Log.info("opened log directory: \(success)")
                    }
                    return
                }

                let fileManager = FileManager.default

                let fileName = DateFormatter(
                    withFormat: "yyyy-MM-dd'T'HHmmssZ",
                    locale: "en_US_POSIX"
                ).string(from: Date()) + "_logs.zip"

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
                        try archive.addEntry(
                            with: backupURL.lastPathComponent,
                            relativeTo: backupURL.deletingLastPathComponent()
                        )
                    } catch {
                        Current.Log.error("Error adding Realm backup to archive!")
                    }

                    if let logFiles = try? fileManager.contentsOfDirectory(
                        at: Constants.LogsDirectory,
                        includingPropertiesForKeys: nil
                    ) {
                        for logFile in logFiles {
                            do {
                                try archive.addEntry(
                                    with: logFile.lastPathComponent,
                                    relativeTo: logFile.deletingLastPathComponent()
                                )
                            } catch {
                                Current.Log.error("Error adding log \(logFile) to archive!")
                            }
                        }
                    }

                    let activityViewController = UIActivityViewController(
                        activityItems: [zipDest],
                        applicationActivities: nil
                    )
                    activityViewController.completionWithItemsHandler = { type, completed, _, _ in
                        let didCancelEntirely = type == nil && !completed
                        let didCompleteEntirely = completed

                        if didCancelEntirely || didCompleteEntirely {
                            try? fileManager.removeItem(at: zipDest)
                        }
                    }
                    self?.present(activityViewController, animated: true, completion: {})
                    if let popOver = activityViewController.popoverPresentationController {
                        popOver.sourceView = cell
                    }
                }
            }

            +++ Section {
                $0.tag = "reset"
                // $0.hidden = Condition(booleanLiteral: !self.configured)
            }
            <<< ButtonRow("resetApp") {
                $0.title = L10n.Settings.ResetSection.ResetRow.title
            }.cellUpdate { cell, _ in
                cell.textLabel?.textColor = .red
            }.onCellSelection { [weak self] cell, row in
                let alert = UIAlertController(
                    title: L10n.Settings.ResetSection.ResetAlert.title,
                    message: L10n.Settings.ResetSection.ResetAlert.message,
                    preferredStyle: UIAlertController.Style.alert
                )

                alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))

                alert.addAction(UIAlertAction(
                    title: L10n.Settings.ResetSection.ResetAlert.title,
                    style: .destructive,
                    handler: { _ in
                        row.hidden = true
                        row.evaluateHidden()
                        self?.ResetApp()
                    }
                ))

                self?.present(alert, animated: true, completion: nil)
                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
            }

            <<< ButtonRow("resetWebData") {
                $0.title = L10n.Settings.ResetSection.ResetWebCache.title
            }.cellUpdate { cell, _ in
                cell.textLabel?.textColor = .red
            }.onCellSelection { _, _ in
                WKWebsiteDataStore.default().removeData(
                    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                    modifiedSince: Date(timeIntervalSince1970: 0),
                    completionHandler: {
                        Current.Log.verbose("Reset browser caches!")
                    }
                )
            }

            +++ Section(header: L10n.Settings.Developer.header, footer: L10n.Settings.Developer.footer) {
                $0.hidden = Condition(booleanLiteral: Current.appConfiguration.rawValue > 1)
                $0.tag = "developerOptions"
            }

            <<< ButtonRow("onboardTest") {
                $0.title = "Onboard"
                $0.presentationMode = .presentModally(controllerProvider: .storyBoard(
                    storyboardId: "navController",
                    storyboardName: "Onboarding",
                    bundle: Bundle.main
                ), onDismiss: nil)
            }.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .center
                cell.accessoryType = .none
                cell.editingAccessoryType = cell.accessoryType
                cell.textLabel?.textColor = cell.tintColor.withAlphaComponent(1.0)
            }

            <<< ButtonRow {
                $0.title = L10n.Settings.Developer.SyncWatchContext.title
            }.onCellSelection { [weak self] cell, _ in
                if let syncError = HomeAssistantAPI.SyncWatchContext() {
                    let alert = UIAlertController(
                        title: L10n.errorLabel,
                        message: syncError.localizedDescription,
                        preferredStyle: .alert
                    )

                    alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))

                    self?.present(alert, animated: true, completion: nil)
                    alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
                }
            }

            <<< ButtonRow {
                $0.title = L10n.Settings.Developer.CopyRealm.title
            }.onCellSelection { [weak self] cell, _ in
                guard let backupURL = Realm.backup() else {
                    fatalError("Unable to get Realm backup")
                }
                let containerRealmPath = Realm.Configuration.defaultConfiguration.fileURL!

                Current.Log.verbose("Would copy from \(backupURL) to \(containerRealmPath)")

                if FileManager.default.fileExists(atPath: containerRealmPath.path) {
                    do {
                        _ = try FileManager.default.removeItem(at: containerRealmPath)
                    } catch {
                        Current.Log.error("Error occurred, here are the details:\n \(error)")
                    }
                }

                do {
                    _ = try FileManager.default.copyItem(at: backupURL, to: containerRealmPath)
                } catch let error as NSError {
                    // Catch fires here, with an NSError being thrown
                    Current.Log.error("Error occurred, here are the details:\n \(error)")
                }

                let msg = L10n.Settings.Developer.CopyRealm.Alert.message(
                    backupURL.path,
                    containerRealmPath.path
                )

                let alert = UIAlertController(
                    title: L10n.Settings.Developer.CopyRealm.Alert.title,
                    message: msg,
                    preferredStyle: UIAlertController.Style.alert
                )

                alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))

                self?.present(alert, animated: true, completion: nil)

                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
            }

            <<< ButtonRow {
                $0.title = L10n.Settings.Developer.DebugStrings.title
            }.onCellSelection { [weak self] cell, _ in
                prefs.set(!prefs.bool(forKey: "showTranslationKeys"), forKey: "showTranslationKeys")

                let alert = UIAlertController(title: L10n.okLabel, message: nil, preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))

                self?.present(alert, animated: true, completion: nil)

                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
            }
            <<< ButtonRow("camera_notification_test") {
                $0.title = L10n.Settings.Developer.CameraNotification.title
            }.onCellSelection { _, _ in
                SettingsViewController.showCameraContentExtension()
            }
            <<< ButtonRow("map_notification_test") {
                $0.title = L10n.Settings.Developer.MapNotification.title
            }.onCellSelection { _, _ in
                SettingsViewController.showMapContentExtension()
            }
            <<< ButtonRow {
                $0.title = L10n.Settings.Developer.CrashlyticsTest.NonFatal.title
            }.onCellSelection { [weak self] cell, _ in
                let alert = UIAlertController(
                    title: L10n.Settings.Developer.CrashlyticsTest.NonFatal.Notification.title,
                    message: L10n.Settings.Developer.CrashlyticsTest.NonFatal.Notification.body,
                    preferredStyle: .alert
                )

                alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: { _ in
                    let userInfo = [
                        NSLocalizedDescriptionKey: NSLocalizedString("The request failed.", comment: ""),
                        NSLocalizedFailureReasonErrorKey: NSLocalizedString(
                            "The response returned a 404.",
                            comment: ""
                        ),
                        NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString("Does this page exist?", comment: ""),
                        "ProductID": "123456",
                        "View": "MainView",
                    ]

                    let error = NSError(domain: NSCocoaErrorDomain, code: -1001, userInfo: userInfo)
                    Current.crashReporter.logError(error)
                }))

                self?.present(alert, animated: true, completion: nil)
                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
            }
            <<< ButtonRow {
                $0.title = L10n.Settings.Developer.CrashlyticsTest.Fatal.title
            }.onCellSelection { [weak self] cell, _ in
                let alert = UIAlertController(
                    title: L10n.Settings.Developer.CrashlyticsTest.Fatal.Notification.title,
                    message: L10n.Settings.Developer.CrashlyticsTest.Fatal.Notification.body,
                    preferredStyle: .alert
                )

                alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: { _ in
                    SentrySDK.crash()
                }))

                self?.present(alert, animated: true, completion: nil)
                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
            }

            <<< SwitchRow {
                $0.title = L10n.Settings.Developer.AnnoyingBackgroundNotifications.title
                $0.value = prefs.bool(forKey: XCGLogger.shouldNotifyUserDefaultsKey)
                $0.onChange { row in
                    prefs.set(row.value ?? false, forKey: XCGLogger.shouldNotifyUserDefaultsKey)
                }
            }
    }

    @objc func openAbout(_ sender: UIButton) {
        let aboutView = AboutViewController()

        let navController = UINavigationController(rootViewController: aboutView)
        show(navController, sender: nil)
    }

    @objc func closeSettings(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    func ResetApp() {
        Current.Log.verbose("Resetting app!")

        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.label.text = L10n.Settings.ResetSection.ResetAlert.progressMessage
        hud.show(animated: true)

        let waitAtLeast = after(seconds: 3.0)

        firstly {
            race(
                Current.tokenManager?.revokeToken().asVoid().recover { _ in () } ?? .value(()),
                after(seconds: 10.0)
            )
        }.then {
            waitAtLeast
        }.get {
            Current.apiConnection.disconnect()

            resetStores()
            setDefaults()
        }.then {
            Current.notificationManager.resetPushID().asVoid().recover { _ in }
        }.ensure {
            hud.hide(animated: true)
            Current.onboardingObservation.needed(.logout)
        }.cauterize()
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            Current.Log.verbose("shake!")
            if shakeCount >= maxShakeCount {
                if let section = form.sectionBy(tag: "developerOptions") {
                    section.hidden = false
                    section.evaluateHidden()
                    tableView.reloadData()

                    let alert = UIAlertController(
                        title: "You did it!",
                        message: "Developer functions unlocked",
                        preferredStyle: UIAlertController.Style.alert
                    )
                    alert.addAction(UIAlertAction(
                        title: L10n.okLabel,
                        style: UIAlertAction.Style.default,
                        handler: nil
                    ))
                    present(alert, animated: true, completion: nil)
                    alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
                }
                return
            }
            shakeCount += 1
        }
    }

    static func showMapContentExtension() {
        let content = UNMutableNotificationContent()
        content.body = L10n.Settings.Developer.MapNotification.Notification.body
        content.sound = .default

        var firstPinLatitude = "40.785091"
        var firstPinLongitude = "-73.968285"

        if Current.appConfiguration == .FastlaneSnapshot,
           let lat = prefs.string(forKey: "mapPin1Latitude"),
           let lon = prefs.string(forKey: "mapPin1Longitude") {
            firstPinLatitude = lat
            firstPinLongitude = lon
        }

        var secondPinLatitude = "40.758896"
        var secondPinLongitude = "-73.985130"

        if Current.appConfiguration == .FastlaneSnapshot,
           let lat = prefs.string(forKey: "mapPin2Latitude"),
           let lon = prefs.string(forKey: "mapPin2Longitude") {
            secondPinLatitude = lat
            secondPinLongitude = lon
        }

        content.userInfo = [
            "homeassistant": [
                "latitude": firstPinLatitude,
                "longitude": firstPinLongitude,
                "second_latitude": secondPinLatitude,
                "second_longitude": secondPinLongitude,
            ],
        ]
        content.categoryIdentifier = "map"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let notificationRequest = UNNotificationRequest(
            identifier: "mapContentExtension",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(notificationRequest)
    }

    static func showCameraContentExtension() {
        let content = UNMutableNotificationContent()
        content.body = L10n.Settings.Developer.CameraNotification.Notification.body
        content.sound = .default

        var entityID = "camera.amcrest_camera"

        if Current.appConfiguration == .FastlaneSnapshot,
           let snapshotEntityID = prefs.string(forKey: "cameraEntityID") {
            entityID = snapshotEntityID
        }

        content.userInfo = ["entity_id": entityID]
        content.categoryIdentifier = "camera"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let notificationRequest = UNNotificationRequest(
            identifier: "cameraContentExtension",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(notificationRequest)
    }
}
