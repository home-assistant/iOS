//
//  SettingsViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import PromiseKit
import SafariServices
import Alamofire
import CoreLocation
import UserNotifications
import Shared
import RealmSwift
import Communicator
import arek
import ZIPFoundation
import Lokalise

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
class SettingsViewController: FormViewController, CLLocationManagerDelegate, SFSafariViewControllerDelegate {
    enum SettingsError: Error {
        case configurationFailed
        case credentialsUnavailable
    }
    var authenticationController: AuthenticationController = AuthenticationController()
    func showAuthenticationViewController(_ viewController: SFSafariViewController) {
        viewController.delegate = self
        self.present(viewController, animated: true, completion: nil)
    }

    weak var delegate: ConnectionInfoChangedDelegate?

    var doneButton: Bool = false

    var showErrorConnectingMessage = false
    var showErrorConnectingMessageError: Error?

    var baseURL: URL?
    var internalBaseURL: URL?
    var internalBaseURLSSID: String?
    var internalBaseURLEnabled: Bool = false
    var basicAuthUsername: String? {
        return (self.form.rowBy(tag: "basicAuthUsername") as? TextRow)?.value
    }
    var basicAuthPassword: String? {
        return (self.form.rowBy(tag: "basicAuthPassword") as? PasswordRow)?.value
    }
    var basicAuthEnabled: Bool {
        return (self.form.rowBy(tag: "basicAuth") as? SwitchRow)?.value ?? false
    }

    var configured = false
    var connectionInfo: ConnectionInfo?
    var tokenInfo: TokenInfo?

    let discovery = Bonjour()

    private var shakeCount = 0
    private var maxShakeCount = 3

    override func viewWillDisappear(_ animated: Bool) {
        NSLog("Stopping Home Assistant discovery")
        self.discovery.stopDiscovery()
        self.discovery.stopPublish()
    }

    override func viewWillAppear(_ animated: Bool) {
        self.title = L10n.Settings.NavigationBar.title
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        self.becomeFirstResponder()

        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(SettingsViewController.PermissionDidChange(_:)),
                           name: NSNotification.Name(rawValue: "permission_change"),
                           object: nil)

        let api = HomeAssistantAPI.authenticatedAPI()

        // Initial state
        let keychain = Constants.Keychain
        self.connectionInfo = Current.settingsStore.connectionInfo
        self.tokenInfo = Current.settingsStore.tokenInfo

        let aboutButton = UIBarButtonItem(title: L10n.Settings.NavigationBar.AboutButton.title,
                                          style: .plain,
                                          target: self,
                                          action: #selector(SettingsViewController.openAbout(_:)))

        self.navigationItem.setLeftBarButton(aboutButton, animated: true)

        if doneButton {
            let closeSelector = #selector(SettingsViewController.closeSettings(_:))
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self,
                                             action: closeSelector)

            self.navigationItem.setRightBarButton(doneButton, animated: true)
        }

        if let connectionInfo = self.connectionInfo {
            self.baseURL = connectionInfo.baseURL
            self.configured = true

            if let url = connectionInfo.internalBaseURL, let ssid = connectionInfo.internalSSID {
                self.internalBaseURL = url
                self.internalBaseURLSSID = ssid
                self.internalBaseURLEnabled = true
            }
        }

        if showErrorConnectingMessage {
            var errDesc = ""
            if let err = showErrorConnectingMessageError?.localizedDescription {
                errDesc = err
            }
            let alert = UIAlertController(title: L10n.Settings.ConnectionErrorNotification.title,
                                          message: L10n.Settings.ConnectionErrorNotification.message(errDesc),
                                          preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
                                          handler: nil))
            self.present(alert, animated: true, completion: nil)

            alert.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        }

        self.configureDiscoveryObservers()

        form
            +++ Section(header: L10n.Settings.DiscoverySection.header, footer: "") {
                $0.tag = "discoveredInstances"
                $0.hidden = true
            }

            +++ Section(header: L10n.Settings.ConnectionSection.header, footer: "")
            <<< URLRow("baseURL") {
                $0.title = L10n.Settings.ConnectionSection.BaseUrl.title
                $0.value = self.baseURL
                $0.placeholder = L10n.Settings.ConnectionSection.BaseUrl.placeholder
            }.onCellHighlightChanged({ (cell, row) in
                if row.isHighlighted == false {
                    if let url = row.value {
                        let cleanUrl = self.cleanBaseURL(baseUrl: url)
                        if !cleanUrl.hasValidScheme {
                            let title = L10n.Settings.ConnectionSection.InvalidUrlSchemeNotification.title
                            let message = L10n.Settings.ConnectionSection.InvalidUrlSchemeNotification.message
                            let alert = UIAlertController(title: title, message: message,
                                                          preferredStyle: UIAlertController.Style.alert)
                            alert.addAction(UIAlertAction(title: L10n.okLabel,
                                                          style: UIAlertAction.Style.default,
                                                          handler: nil))
                            self.present(alert, animated: true, completion: nil)
                            alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
                        } else {
                            self.baseURL = cleanUrl.cleanedURL
                        }
                    }
                }
            })
            <<< SwitchRow("showAdvancedConnectionSettings") {
                $0.title = L10n.Settings.ConnectionSection.ShowAdvancedSettingsRow.title
                $0.value = Current.settingsStore.showAdvancedConnectionSettings
            }.onChange { switchRow in
                guard let advancedSection = self.form.sectionBy(tag: "advancedConnectionSettings") else {
                    return
                }

                Current.settingsStore.showAdvancedConnectionSettings = switchRow.value ?? false
                advancedSection.hidden = Condition(booleanLiteral: !(switchRow.value ?? false))
                advancedSection.evaluateHidden()
                self.tableView.reloadData()
            }
            +++ Section(header: L10n.Settings.AdvancedConnectionSettingsSection.title, footer: "") {
                $0.tag = "advancedConnectionSettings"
                $0.hidden = Condition(booleanLiteral: !Current.settingsStore.showAdvancedConnectionSettings)
            }
            <<< SwitchRow("internalUrl") {
                $0.title = L10n.Settings.ConnectionSection.UseInternalUrl.title
                $0.value = self.internalBaseURLEnabled
            }.onChange { row in
                if let boolVal = row.value {
                    Current.Log.verbose("Setting rows to val \(!boolVal)")
                    self.internalBaseURLEnabled = boolVal
                    let ssidRow: LabelRow = self.form.rowBy(tag: "ssid")!
                    ssidRow.hidden = Condition(booleanLiteral: !boolVal)
                    ssidRow.evaluateHidden()
                    let internalURLRow: URLRow = self.form.rowBy(tag: "internalBaseURL")!
                    internalURLRow.hidden = Condition(booleanLiteral: !boolVal)
                    internalURLRow.evaluateHidden()
                    let connectRow: ButtonRow = self.form.rowBy(tag: "connect")!
                    connectRow.evaluateHidden()
                    connectRow.updateCell()
                    let externalURLRow: URLRow = self.form.rowBy(tag: "baseURL")!
                    if boolVal == true {
                        externalURLRow.title = L10n.Settings.ConnectionSection.ExternalBaseUrl.title
                    } else {
                        externalURLRow.title = L10n.Settings.ConnectionSection.BaseUrl.title
                    }
                    externalURLRow.updateCell()
                    self.tableView.reloadData()
                }
            }

            <<< LabelRow("ssid") {
                $0.title = L10n.Settings.ConnectionSection.NetworkName.title
                $0.value = L10n.ClientEvents.EventType.unknown
                $0.hidden = Condition(booleanLiteral: !self.internalBaseURLEnabled)
                if let ssid = self.internalBaseURLSSID {
                    $0.value = ssid
                } else if let ssid = ConnectionInfo.currentSSID() {
                    $0.value = ssid
                }
                self.internalBaseURLSSID = $0.value
            }

            <<< URLRow("internalBaseURL") {
                $0.title = L10n.Settings.ConnectionSection.InternalBaseUrl.title
                $0.value = self.internalBaseURL
                $0.placeholder = "http://hassio.local:8123"
                $0.hidden = Condition(booleanLiteral: !self.internalBaseURLEnabled)
            }.onCellHighlightChanged({ (cell, row) in
                if row.isHighlighted == false {
                    if let url = row.value {
                        let cleanUrl = self.cleanBaseURL(baseUrl: url)
                        if !cleanUrl.hasValidScheme {
                            let title = L10n.Settings.ConnectionSection.InvalidUrlSchemeNotification.title
                            let message = L10n.Settings.ConnectionSection.InvalidUrlSchemeNotification.message
                            let alert = UIAlertController(title: title, message: message,
                                                          preferredStyle: UIAlertController.Style.alert)
                            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
                                                          handler: nil))
                            self.present(alert, animated: true, completion: nil)
                            alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
                        } else {
                            self.internalBaseURL = cleanUrl.cleanedURL
                        }
                    }
                }
            })

            <<< SwitchRow("basicAuth") {
                $0.title = L10n.Settings.ConnectionSection.BasicAuth.title
                $0.value = (self.connectionInfo?.basicAuthCredentials != nil)
            }.onChange { row in
                if let boolVal = row.value {
                    Current.Log.verbose("Setting rows to val \(!boolVal)")
                    let cond = Condition(booleanLiteral: !boolVal)
                    let basicAuthUsername: TextRow = self.form.rowBy(tag: "basicAuthUsername")!
                    basicAuthUsername.hidden = cond
                    basicAuthUsername.evaluateHidden()
                    let basicAuthPassword: PasswordRow = self.form.rowBy(tag: "basicAuthPassword")!
                    basicAuthPassword.hidden = cond
                    basicAuthPassword.evaluateHidden()
                    self.tableView.reloadData()
                }
            }

            <<< TextRow("basicAuthUsername") {
                $0.title = L10n.Settings.ConnectionSection.BasicAuth.Username.title
                $0.hidden = Condition(booleanLiteral: (self.connectionInfo?.basicAuthCredentials == nil))
                $0.value = self.connectionInfo?.basicAuthCredentials?.username ?? ""
                $0.placeholder = L10n.Settings.ConnectionSection.BasicAuth.Username.placeholder
            }

            <<< PasswordRow("basicAuthPassword") {
                $0.title = L10n.Settings.ConnectionSection.BasicAuth.Password.title
                $0.value = self.connectionInfo?.basicAuthCredentials?.password ?? ""
                $0.placeholder = L10n.Settings.ConnectionSection.BasicAuth.Password.placeholder
                $0.hidden = Condition(booleanLiteral: (self.connectionInfo?.basicAuthCredentials == nil))
            }.cellUpdate { cell, row in
                if !row.isValid {
                    cell.titleLabel?.textColor = .red
                }
            }
            +++ Section(header: "", footer: "")
            <<< ButtonRow("connect") {
                    $0.title = L10n.Settings.ConnectionSection.SaveButton.title
                }.onCellSelection { _, _ in
                    if self.form.validate().count == 0 {
                        _ = self.validateConnection()
                    }
                }
            +++ Section(header: L10n.Settings.StatusSection.header, footer: "") {
                $0.tag = "status"
                $0.hidden = Condition(booleanLiteral: !self.configured)
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
            <<< LabelRow("mobileAppComponentLoaded") {
                $0.title = L10n.Settings.StatusSection.MobileAppComponentLoadedRow.title
                $0.value = api?.mobileAppComponentLoaded ?? false ? "✔️" : "✖️"
            }

            +++ Section(header: "", footer: L10n.Settings.DeviceIdSection.footer)
            <<< TextRow("deviceId") {
                $0.title = L10n.Settings.DeviceIdSection.DeviceIdRow.title
                $0.value = Current.settingsStore.deviceID
                $0.cell.textField.autocapitalizationType = .none
                }.cellUpdate { _, row in
                    if row.isHighlighted == false {
                        if let deviceId = row.value {
                            Current.settingsStore.deviceID = deviceId
                        }
                    }
            }
            +++ Section {
                $0.tag = "details"
                $0.hidden = Condition(booleanLiteral: !self.configured)
            }
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

            <<< ButtonRow("enableLocation") {
                $0.title = L10n.Settings.DetailsSection.EnableLocationRow.title
                $0.hidden = Condition(booleanLiteral: Current.settingsStore.locationEnabled)
            }.onCellSelection { _, row in
                let permission = LocationPermission()

                permission.manage { status in
                    Current.Log.verbose("Location status \(status)")

                    Current.settingsStore.locationEnabled = (status == .authorized)

                    row.hidden = true
                    row.updateCell()
                    row.evaluateHidden()
                    let locationSettingsRow: ButtonRow = self.form.rowBy(tag: "locationSettings")!
                    locationSettingsRow.hidden = false
                    locationSettingsRow.updateCell()
                    self.tableView.reloadData()
                    if prefs.bool(forKey: "locationUpdateOnZone") == false {
                        Current.syncMonitoredRegions?()
                    }
                    //            _ = HomeAssistantAPI.sharedInstance.getAndSendLocation(trigger: .Manual)
                }
            }

            <<< ButtonRow("locationSettings") {
                $0.title = L10n.Settings.DetailsSection.LocationSettingsRow.title
                $0.hidden = Condition(booleanLiteral: !(Current.settingsStore.locationEnabled))
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    let view = SettingsDetailViewController()
                    view.detailGroup = "location"
                    return view
                    }, onDismiss: { vc in
                        _ = vc.navigationController?.popViewController(animated: true)
                })
            }

            <<< ButtonRow("enableNotifications") {
                $0.title = L10n.Settings.DetailsSection.EnableNotificationRow.title
                $0.hidden = Condition(booleanLiteral: Current.settingsStore.notificationsEnabled)
                }.onCellSelection { _, row in
                    let permission = NotificationPermission()

                    permission.manage { status in
                        Current.Log.verbose("Notification status \(status)")

                        Current.settingsStore.notificationsEnabled = (status == .authorized)

                        if status == .authorized {
                            row.hidden = true
                            row.updateCell()
                            row.evaluateHidden()
                            let settingsRow: ButtonRow = self.form.rowBy(tag: "notificationSettings")!
                            settingsRow.hidden = false
                            settingsRow.evaluateHidden()
                            self.tableView.reloadData()
                        }
                    }
            }

            <<< ButtonRow("notificationSettings") {
                $0.title = L10n.Settings.DetailsSection.NotificationSettingsRow.title
                $0.hidden = Condition(booleanLiteral: !(Current.settingsStore.notificationsEnabled))
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    let view = SettingsDetailViewController()
                    view.detailGroup = "notifications"
                    return view
                    }, onDismiss: { vc in
                        _ = vc.navigationController?.popViewController(animated: true)
                })
            }

        +++ Section(header: L10n.Settings.DetailsSection.Integrations.header, footer: "")
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
            $0.hidden = Condition(booleanLiteral: !self.configured)
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
            $0.tag = "privacy"
            $0.title = L10n.SettingsDetails.Privacy.title
            $0.hidden = true
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "privacy"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // swiftlint:disable:next function_body_length
    @objc func HomeAssistantDiscovered(_ notification: Notification) {
        let discoverySection: Section = self.form.sectionBy(tag: "discoveredInstances")!
        discoverySection.hidden = false
        discoverySection.evaluateHidden()
        if let userInfo = (notification as Notification).userInfo as? [String: Any] {
            guard let discoveryInfo = DiscoveryInfoResponse(JSON: userInfo) else {
                Current.clientEventStore.addEvent(ClientEvent(text: "Unable to parse discovered HA Instance",
                                                              type: .unknown, payload: userInfo))
                return
            }

            var url = discoveryInfo.BaseURL?.host ?? "Unknown"
            let scheme = discoveryInfo.BaseURL?.scheme ?? "Unknown"

            if let baseURL = discoveryInfo.BaseURL, let host = baseURL.host, let port = baseURL.port {
                url = "\(host):\(port)"
            }

            let detailTextLabel = "\(url) - \(discoveryInfo.Version) - \(scheme.uppercased())"
            if self.form.rowBy(tag: discoveryInfo.LocationName) == nil {
                discoverySection
                    <<< ButtonRow(discoveryInfo.LocationName) {
                            $0.title = discoveryInfo.LocationName
                            $0.cellStyle = UITableViewCell.CellStyle.subtitle
                        }.cellUpdate { cell, _ in
                            cell.textLabel?.textColor = .black
                            cell.detailTextLabel?.text = detailTextLabel
                        }.onCellSelection({ _, _ in
                            self.connectionInfo = nil
                            self.tokenInfo = nil
                            self.baseURL = discoveryInfo.BaseURL
                            let urlRow: URLRow = self.form.rowBy(tag: "baseURL")!
                            urlRow.value = discoveryInfo.BaseURL
                            urlRow.updateCell()
                            self.tableView?.reloadData()
                        })
                self.tableView?.reloadData()
            } else {
                if let readdedRow: ButtonRow = self.form.rowBy(tag: discoveryInfo.LocationName) {
                    readdedRow.hidden = false
                    readdedRow.updateCell()
                    readdedRow.evaluateHidden()
                    self.tableView?.reloadData()
                }
            }
        }
        self.tableView.reloadData()
    }

    @objc func HomeAssistantUndiscovered(_ notification: Notification) {
        if let userInfo = (notification as Notification).userInfo {
            if let stringedName = userInfo["name"] as? String {
                if let removingRow: ButtonRow = self.form.rowBy(tag: stringedName) {
                    removingRow.hidden = true
                    removingRow.evaluateHidden()
                    removingRow.updateCell()
                }
            }
        }
        let discoverySection: Section = self.form.sectionBy(tag: "discoveredInstances")!
        discoverySection.hidden = Condition(booleanLiteral: (discoverySection.count < 1))
        discoverySection.evaluateHidden()
        self.tableView.reloadData()
    }

    @objc func Connected(_ notification: Notification) {
        let mobileAppComponentLoadedRow: LabelRow = self.form.rowBy(tag: "mobileAppComponentLoaded")!
        let api = HomeAssistantAPI.authenticatedAPI()
        mobileAppComponentLoadedRow.value = api?.mobileAppComponentLoaded ?? false ? "✔️" : "✖️"
        mobileAppComponentLoadedRow.updateCell()
    }

    func ResetApp() {
        Current.Log.verbose("Resetting app!")
        resetStores()
        let bundleId = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: bundleId)
        UserDefaults.standard.synchronize()
        prefs.removePersistentDomain(forName: bundleId)
        prefs.synchronize()
        let urlRow: URLRow = self.form.rowBy(tag: "baseURL")!
        urlRow.value = nil
        urlRow.updateCell()
        let statusSection: Section = self.form.sectionBy(tag: "status")!
        statusSection.hidden = true
        statusSection.evaluateHidden()
        let detailsSection: Section = self.form.sectionBy(tag: "details")!
        detailsSection.hidden = true
        detailsSection.evaluateHidden()
        self.tableView.reloadData()

        let keys = keychain.allKeys()
        for key in keys {
            keychain[key] = nil
        }
    }

    /// Grab the connection info from fields in the UI.
    private func connectionInfoFromUI() -> ConnectionInfo? {
        if let baseURL = self.baseURL {
            let credentials: ConnectionInfo.BasicAuthCredentials?
            if self.basicAuthEnabled, let username = self.basicAuthUsername,
                let password = self.basicAuthPassword {
                credentials = ConnectionInfo.BasicAuthCredentials(username: username, password: password)
            } else {
                credentials = nil
            }

            let internalURL = self.internalBaseURLEnabled ? self.internalBaseURL : nil
            let internalSSID = self.internalBaseURLEnabled ? self.internalBaseURLSSID : nil
            let connectionInfo = ConnectionInfo(baseURL: baseURL,
                                                internalBaseURL: internalURL,
                                                internalSSID: internalSSID,
                                                basicAuthCredentials: credentials)
            return connectionInfo
        }

        return nil
    }

    private func handleConnectionError(_ error: (Error)) {
        Current.Log.error("Connection error: \(error)")
        var errorMessage = error.localizedDescription
        if let error = error as? AFError {
            if error.responseCode == 401 {
                errorMessage = L10n.Settings.ConnectionError.Forbidden.message
            }
        }

        let title = L10n.Settings.ConnectionErrorNotification.title
        let message = L10n.Settings.ConnectionErrorNotification.message(errorMessage)
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: L10n.okLabel,
                                      style: UIAlertAction.Style.default,
                                      handler: nil))
        self.present(alert, animated: true, completion: nil)

        alert.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
    }

    /// Resolves to the connection info used to connect. As a side effect, the successful tokenInfo is stored.
    private func confirmConnection(with connectionInfo: ConnectionInfo) -> Promise<ConnectionInfo> {
        let tryExistingCredentials: () -> Promise<ConfigResponse> = {
            if let existingTokenInfo = self.tokenInfo {
                let api = HomeAssistantAPI(connectionInfo: connectionInfo,
                                           tokenInfo: existingTokenInfo)
                return api.GetConfig()
            } else {
                return Promise(error: SettingsError.credentialsUnavailable)
            }
        }

        return Promise { seal in
            firstly {
                tryExistingCredentials()
            }.done { _ in
                _ = seal.fulfill(connectionInfo)
            }.catch { innerError in
                let confirmWithBrowser = {
                    self.authenticateThenConfirmConnection(with: connectionInfo).done { connectionInfo in
                        seal.fulfill(connectionInfo)
                        }.catch { browserFlowError in
                            seal.reject(browserFlowError)
                    }
                }

                if case SettingsError.credentialsUnavailable = innerError {
                    _ = confirmWithBrowser()
                    return
                }

                if let afError = innerError as? AFError,
                    case .responseValidationFailed(reason: let reason) = afError,
                    case .unacceptableStatusCode(code: let code) = reason, code == 401 {
                    _ = confirmWithBrowser()
                    return
                }

                seal.reject(innerError)
            }
        }
    }

    private func authenticateThenConfirmConnection(with connectionInfo: ConnectionInfo) ->
        Promise<ConnectionInfo> {
            Current.Log.verbose("Attempting browser auth to: \(connectionInfo.activeURL)")
            return firstly {
                self.authenticationController.authenticateWithBrowser(at: connectionInfo.activeURL)
            }.then { (code: String) -> Promise<String> in
                Current.Log.verbose("Browser auth succeeded, getting token")
                let tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: nil)
                return tokenManager.initialTokenWithCode(code)
            }.then { _ -> Promise<ConnectionInfo> in
                Current.Log.verbose("Token acquired")
                return Promise.value(connectionInfo)
            }
    }

    /// Attempt to connect to the server with the supplied credentials. If it succeeds, save those
    /// credentials and update the UI
    // swiftlint:disable:next function_body_length
    private func validateConnection() -> Bool {
       guard let connectionInfo = self.connectionInfoFromUI() else {
            let errMsg = L10n.Settings.ConnectionError.InvalidUrl.message
            let alert = UIAlertController(title: L10n.Settings.ConnectionError.InvalidUrl.title,
                                          message: errMsg,
                                          preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel,
                                          style: UIAlertAction.Style.default,
                                          handler: nil))
            self.present(alert, animated: true, completion: nil)
            alert.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
            return false
        }

        _ = firstly {
            self.confirmConnection(with: connectionInfo)
        }.then { confirmedConnectionInfo -> Promise<ConfigResponse> in
            // At this point we are authenticated with modern auth. Clear legacy password.
            Current.Log.info("Confirmed connection to server: \(connectionInfo.activeURL)")
            let keychain = Constants.Keychain
            keychain["apiPassword"] = nil
            Current.settingsStore.connectionInfo = confirmedConnectionInfo
            guard let tokenInfo = Current.settingsStore.tokenInfo else {
                Current.Log.warning("No token available when we think there should be")
                throw SettingsError.configurationFailed
            }

            let api = HomeAssistantAPI(connectionInfo: confirmedConnectionInfo, tokenInfo: tokenInfo)
            Current.updateWith(authenticatedAPI: api)
            _ = HomeAssistantAPI.SyncWatchContext()
            return api.Connect()
        }.done { config in
            Current.Log.verbose("Getting current configuration successful. Updating UI")
            self.configureUIWith(configResponse: config)
        }.catch { error in
            self.handleConnectionError(error)
        }

        return true
    }

    private func configureDiscoveryObservers() {
        let queue = DispatchQueue(label: Bundle.main.bundleIdentifier!, attributes: [])
        queue.async { () -> Void in
            self.discovery.stopDiscovery()
            self.discovery.stopPublish()

            self.discovery.startDiscovery()
            self.discovery.startPublish()
        }

        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(SettingsViewController.HomeAssistantDiscovered(_:)),
                           name: NSNotification.Name(rawValue: "homeassistant.discovered"),
                           object: nil)

        center.addObserver(self,
                           selector: #selector(SettingsViewController.HomeAssistantUndiscovered(_:)),
                           name: NSNotification.Name(rawValue: "homeassistant.undiscovered"),
                           object: nil)

        center.addObserver(self,
                           selector: #selector(SettingsViewController.Connected(_:)),
                           name: NSNotification.Name(rawValue: "connected"),
                           object: nil)
    }
    private func configureUIWith(configResponse config: ConfigResponse) {
        Current.Log.verbose("Connected!")
        self.form.setValues(["locationName": config.LocationName, "version": config.Version])
        let locationNameRow: LabelRow = self.form.rowBy(tag: "locationName")!
        locationNameRow.updateCell()
        let versionRow: LabelRow = self.form.rowBy(tag: "version")!
        versionRow.updateCell()
        let statusSection: Section = self.form.sectionBy(tag: "status")!
        statusSection.hidden = false
        statusSection.evaluateHidden()
        let detailsSection: Section = self.form.sectionBy(tag: "details")!
        detailsSection.hidden = false
        detailsSection.evaluateHidden()
        let closeSelector = #selector(SettingsViewController.closeSettings(_:))
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self,
                                         action: closeSelector)
        self.navigationItem.setRightBarButton(doneButton, animated: true)
        self.tableView.reloadData()
        self.delegate?.userReconnected()
    }

    @objc func openAbout(_ sender: UIButton) {
        let aboutView = AboutViewController()

        let navController = UINavigationController(rootViewController: aboutView)
        self.show(navController, sender: nil)
        //        self.present(navController, animated: true, completion: nil)
    }

    @objc func closeSettings(_ sender: UIButton) {
        if self.form.validate().count == 0 && self.validateConnection() == true &&
            Current.settingsStore.connectionInfo != nil {
            self.dismiss(animated: true, completion: nil)
        }
    }

    func cleanBaseURL(baseUrl: URL) -> (hasValidScheme: Bool, cleanedURL: URL) {
        if (baseUrl.absoluteString.hasPrefix("http://") || baseUrl.absoluteString.hasPrefix("https://")) == false {
            return (false, baseUrl)
        }
        var urlComponents = URLComponents()
        urlComponents.scheme = baseUrl.scheme
        urlComponents.host = baseUrl.host
        urlComponents.port = baseUrl.port
        //        if urlComponents.port == nil {
        //            urlComponents.port = (baseUrl.scheme == "http") ? 80 : 443
        //        }
        return (true, urlComponents.url!)
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

    @objc func PermissionDidChange(_ notification: Notification) {
        if let userInfo = (notification as Notification).userInfo as? [String: Any] {
            if let locationChange = userInfo["location"] as? Bool {
                Current.Log.verbose("Location granted? \(locationChange)")

                DispatchQueue.main.async {
                    let enableLocationRow: ButtonRow = self.form.rowBy(tag: "enableLocation")!
                    enableLocationRow.hidden = Condition(booleanLiteral: locationChange)
                    enableLocationRow.updateCell()
                    enableLocationRow.evaluateHidden()
                    let locationSettingsRow: ButtonRow = self.form.rowBy(tag: "locationSettings")!
                    locationSettingsRow.hidden = Condition(booleanLiteral: !locationChange)
                    locationSettingsRow.updateCell()
                    locationSettingsRow.evaluateHidden()
                    self.tableView.reloadData()
                    if prefs.bool(forKey: "locationUpdateOnZone") == false {
                        Current.syncMonitoredRegions?()
                    }
                }
            }
            if let notificationsChange = userInfo["notifications"] as? Bool {
                Current.Log.verbose("Notifications granted? \(notificationsChange)")

                DispatchQueue.main.async {
                    let enableNotificationsRow: ButtonRow = self.form.rowBy(tag: "enableNotifications")!
                    enableNotificationsRow.hidden = Condition(booleanLiteral: notificationsChange)
                    enableNotificationsRow.updateCell()
                    enableNotificationsRow.evaluateHidden()
                    let settingsRow: ButtonRow = self.form.rowBy(tag: "notificationSettings")!
                    settingsRow.hidden = Condition(booleanLiteral: !notificationsChange)
                    settingsRow.evaluateHidden()
                    self.tableView.reloadData()
                }
            }
        }
    }
}

protocol ConnectionInfoChangedDelegate: class {
    func userReconnected()
}
