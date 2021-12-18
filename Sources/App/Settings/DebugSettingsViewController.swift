import Eureka
import MBProgressHUD
import PromiseKit
import RealmSwift
import Shared
import WebKit
import XCGLogger

class DebugSettingsViewController: HAFormViewController {
    private var shakeCount = 0
    private var maxShakeCount = 3

    override init() {
        super.init()

        title = L10n.Settings.Debugging.title
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        becomeFirstResponder()

        form.append(contentsOf: [
            logs(),
            reset(),
            developerOptions(),
        ])
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

    private func logs() -> Section {
        let section = Section()

        section <<< SettingsButtonRow {
            $0.title = L10n.Settings.EventLog.title

            let scene = StoryboardScene.ClientEvents.self
            $0.presentationMode = .show(controllerProvider: .storyBoard(
                storyboardId: scene.clientEventsList.identifier,
                storyboardName: scene.storyboardName,
                bundle: Bundle.main
            ), onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        section <<< SettingsButtonRow {
            $0.title = L10n.Settings.LocationHistory.title
            $0.presentationMode = .show(controllerProvider: .callback(builder: {
                LocationHistoryListViewController()
            }), onDismiss: nil)
        }

        return section
    }

    private func reset() -> Section {
        let section = Section()

        section <<< ButtonRow {
            if Current.isCatalyst {
                $0.title = L10n.Settings.Developer.ShowLogFiles.title
            } else {
                $0.title = L10n.Settings.Developer.ExportLogFiles.title
            }
            $0.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .natural
            }
        }.onCellSelection { [weak self] cell, _ in
            guard let self = self else { return }
            Current.Log.export(from: self, sender: cell, openURLHandler: { url in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            })
        }

        section <<< SettingsButtonRow {
            $0.isDestructive = true
            $0.title = L10n.Settings.ResetSection.ResetWebCache.title
            $0.onCellSelection { [weak self] _, _ in
                guard let self = self else { return }

                let hud = MBProgressHUD.showAdded(to: self.view.window ?? self.view, animated: true)
                hud.backgroundView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)

                let (promise, seal) = Guarantee<Void>.pending()

                WKWebsiteDataStore.default().removeData(
                    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                    modifiedSince: Date(timeIntervalSince1970: 0),
                    completionHandler: {
                        Current.Log.verbose("Reset browser caches!")
                        seal(())
                    }
                )

                when(promise, after(seconds: 2.0)).done { _ in
                    hud.hide(animated: true)
                }
            }
        }

        section <<< SettingsButtonRow {
            $0.isDestructive = true
            $0.title = L10n.Settings.ResetSection.ResetRow.title
            $0.onCellSelection { [weak self] cell, row in
                let alert = UIAlertController(
                    title: L10n.Settings.ResetSection.ResetAlert.title,
                    message: L10n.Settings.ResetSection.ResetAlert.message,
                    preferredStyle: .actionSheet
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

                with(alert.popoverPresentationController) {
                    $0?.sourceView = cell
                    $0?.sourceRect = cell.bounds
                }

                self?.present(alert, animated: true, completion: nil)
            }
        }

        return section
    }

    private func developerOptions() -> Section {
        let section = Section(header: L10n.Settings.Developer.header, footer: L10n.Settings.Developer.footer) {
            $0.hidden = Condition(booleanLiteral: Current.appConfiguration.rawValue > 1)
            $0.tag = "developerOptions"
        }

        section <<< ButtonRow("onboardTest") {
            $0.title = "Onboard (Initial)"
            $0.presentationMode = .presentModally(controllerProvider: .callback(builder: {
                OnboardingNavigationViewController(onboardingStyle: .initial)
            }), onDismiss: nil)
        }.cellUpdate { cell, _ in
            cell.textLabel?.textAlignment = .center
            cell.accessoryType = .none
            cell.editingAccessoryType = cell.accessoryType
            cell.textLabel?.textColor = cell.tintColor.withAlphaComponent(1.0)
        }

        section <<< ButtonRow {
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

        section <<< ButtonRow {
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

        section <<< ButtonRow {
            $0.title = L10n.Settings.Developer.DebugStrings.title
        }.onCellSelection { [weak self] cell, _ in
            prefs.set(!prefs.bool(forKey: "showTranslationKeys"), forKey: "showTranslationKeys")

            let alert = UIAlertController(title: L10n.okLabel, message: nil, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))

            self?.present(alert, animated: true, completion: nil)

            alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
        }
        section <<< ButtonRow("camera_notification_test") {
            $0.title = L10n.Settings.Developer.CameraNotification.title
        }.onCellSelection { _, _ in
            Self.showCameraContentExtension()
        }
        section <<< ButtonRow("map_notification_test") {
            $0.title = L10n.Settings.Developer.MapNotification.title
        }.onCellSelection { _, _ in
            Self.showMapContentExtension()
        }
        section <<< ButtonRow {
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
        section <<< ButtonRow {
            $0.title = L10n.Settings.Developer.CrashlyticsTest.Fatal.title
        }.onCellSelection { [weak self] cell, _ in
            let alert = UIAlertController(
                title: L10n.Settings.Developer.CrashlyticsTest.Fatal.Notification.title,
                message: L10n.Settings.Developer.CrashlyticsTest.Fatal.Notification.body,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: { _ in
//                SentrySDK.crash()
            }))

            self?.present(alert, animated: true, completion: nil)
            alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
        }

        section <<< SwitchRow {
            $0.title = L10n.Settings.Developer.AnnoyingBackgroundNotifications.title
            $0.value = prefs.bool(forKey: XCGLogger.shouldNotifyUserDefaultsKey)
            $0.onChange { row in
                prefs.set(row.value ?? false, forKey: XCGLogger.shouldNotifyUserDefaultsKey)
            }
        }

        return section
    }

    func ResetApp() {
        Current.Log.verbose("Resetting app!")

        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.label.text = L10n.Settings.ResetSection.ResetAlert.progressMessage
        hud.show(animated: true)

        let waitAtLeast = after(seconds: 3.0)

        firstly {
            race(
                when(resolved: Current.apis.map { $0.tokenManager.revokeToken() }).asVoid(),
                after(seconds: 10.0)
            )
        }.then {
            waitAtLeast
        }.get {
            Current.apis.map(\.connection).forEach { $0.disconnect() }
            Current.servers.removeAll()
            resetStores()
            setDefaults()
        }.then {
            Current.notificationManager.resetPushID().asVoid().recover { _ in }
        }.ensure {
            hud.hide(animated: true)
            Current.onboardingObservation.needed(.logout)
        }.cauterize()
    }
}
