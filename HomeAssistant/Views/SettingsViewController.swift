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
import KeychainAccess
import CoreLocation
import UserNotifications
import Shared
import SystemConfiguration.CaptiveNetwork
import RealmSwift
import Communicator
import arek

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
    var legacyPassword: String?
    var internalBaseURL: URL?
    var internalBaseURLSSID: String?
    var internalBaseURLEnabled: Bool = false
    var basicAuthUsername: String?
    var basicAuthPassword: String?
    var basicAuthEnabled: Bool = false
    var useLegacyAuth: Bool = false

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
        let keychain = Keychain(service: Bundle.main.bundleIdentifier!)
        self.legacyPassword = keychain["apiPassword"]
        self.useLegacyAuth = Current.settingsStore.tokenInfo == nil && self.legacyPassword != nil
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
            }.onCellHighlightChanged({ (_, row) in
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
                        } else {
                            self.baseURL = cleanUrl.cleanedURL
                        }
                    }
                }
            })
            <<< SwitchRow("useLegacyAuth") {
                $0.title = L10n.Settings.ConnectionSection.UseLegacyAuth.title
                $0.value = self.useLegacyAuth
                }.onChange { switchRow in
                    guard let passwordRow = self.form.rowBy(tag: "apiPassword") else {
                        return
                    }

                    self.useLegacyAuth = switchRow.value ?? false
                    passwordRow.hidden = Condition(booleanLiteral: !(switchRow.value ?? false))
                    passwordRow.evaluateHidden()
                    self.tableView.reloadData()
            }
            <<< PasswordRow("apiPassword") {
                $0.title = L10n.Settings.ConnectionSection.ApiPasswordRow.title
                $0.value = self.legacyPassword
                $0.placeholder = L10n.Settings.ConnectionSection.ApiPasswordRow.placeholder
                $0.hidden = Condition(booleanLiteral: !self.useLegacyAuth)
                }.onChange { row in
                    self.legacyPassword = row.value
                }.cellUpdate { cell, row in
                    if !row.isValid {
                        cell.titleLabel?.textColor = .red
                    }
            }
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
                    print("Setting rows to val", !boolVal)
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
            }.onCellHighlightChanged({ (_, row) in
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
                        } else {
                            self.internalBaseURL = cleanUrl.cleanedURL
                        }
                    }
                }
            })

            <<< SwitchRow("basicAuth") {
                $0.title = L10n.Settings.ConnectionSection.BasicAuth.title
                $0.value = self.basicAuthEnabled
            }.onChange { row in
                if let boolVal = row.value {
                    print("Setting rows to val", !boolVal)
                    self.basicAuthEnabled = boolVal
                    let basicAuthUsername: TextRow = self.form.rowBy(tag: "basicAuthUsername")!
                    basicAuthUsername.hidden = Condition(booleanLiteral: !boolVal)
                    basicAuthUsername.evaluateHidden()
                    let basicAuthPassword: PasswordRow = self.form.rowBy(tag: "basicAuthPassword")!
                    basicAuthPassword.hidden = Condition(booleanLiteral: !boolVal)
                    basicAuthPassword.evaluateHidden()
                    self.tableView.reloadData()
                }
            }

            <<< TextRow("basicAuthUsername") {
                $0.title = L10n.Settings.ConnectionSection.BasicAuth.Username.title
                $0.hidden = Condition(booleanLiteral: !self.basicAuthEnabled)
                $0.value = self.connectionInfo?.basicAuthCredentials?.username ?? ""
                $0.placeholder = L10n.Settings.ConnectionSection.BasicAuth.Username.placeholder
            }.onChange { row in
                self.basicAuthUsername = row.value
            }

            <<< PasswordRow("basicAuthPassword") {
                $0.title = L10n.Settings.ConnectionSection.BasicAuth.Password.title
                $0.value = self.connectionInfo?.basicAuthCredentials?.password ?? ""
                $0.placeholder = L10n.Settings.ConnectionSection.BasicAuth.Password.placeholder
                $0.hidden = Condition(booleanLiteral: !self.basicAuthEnabled)
            }.onChange { row in
                self.basicAuthPassword = row.value
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
            <<< LabelRow("iosComponentLoaded") {
                $0.title = L10n.Settings.StatusSection.IosComponentLoadedRow.title
                $0.value = api?.iosComponentLoaded ?? false ? "✔️" : "✖️"
            }
            <<< LabelRow("deviceTrackerComponentLoaded") {
                $0.title = L10n.Settings.StatusSection.DeviceTrackerComponentLoadedRow.title
                $0.value = api?.deviceTrackerComponentLoaded ?? false ? "✔️" : "✖️"
                $0.hidden = Condition(booleanLiteral: !(Current.settingsStore.locationEnabled))
            }
            <<< LabelRow("notifyPlatformLoaded") {
                $0.title = L10n.Settings.StatusSection.NotifyPlatformLoadedRow.title
                $0.value = api?.iosNotifyPlatformLoaded ?? false ? "✔️" : "✖️"
                $0.hidden = Condition(booleanLiteral: !(Current.settingsStore.notificationsEnabled))
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
                $0.hidden = Condition(booleanLiteral: !OpenInChromeController().isChromeInstalled())
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
                    print("Location status", status)

                    Current.settingsStore.locationEnabled = (status == .authorized)

                    row.hidden = true
                    row.updateCell()
                    row.evaluateHidden()
                    let locationSettingsRow: ButtonRow = self.form.rowBy(tag: "locationSettings")!
                    locationSettingsRow.hidden = false
                    locationSettingsRow.updateCell()
                    locationSettingsRow.evaluateHidden()
                    let deviceTrackerComponentLoadedRow: LabelRow = self.form.rowBy(
                        tag: "deviceTrackerComponentLoaded")!
                    deviceTrackerComponentLoadedRow.hidden = false
                    deviceTrackerComponentLoadedRow.evaluateHidden()
                    deviceTrackerComponentLoadedRow.updateCell()
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
                        print("Notification status", status)

                        Current.settingsStore.notificationsEnabled = (status == .authorized)

                        if status == .authorized {
                            row.hidden = true
                            row.updateCell()
                            row.evaluateHidden()
                            let settingsRow: ButtonRow = self.form.rowBy(tag: "notificationSettings")!
                            settingsRow.hidden = false
                            settingsRow.evaluateHidden()
                            let loadedRow: LabelRow = self.form.rowBy(tag: "notifyPlatformLoaded")!
                            loadedRow.hidden = false
                            loadedRow.evaluateHidden()
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

            +++ ButtonRow("eventLog") {
                $0.title = L10n.Settings.EventLog.title
                let controllerProvider = ControllerProvider.storyBoard(storyboardId: "clientEventsList",
                                                                       storyboardName: "ClientEvents",
                                                                       bundle: Bundle.main)
                $0.presentationMode = .show(controllerProvider: controllerProvider, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
                })
            }

        +++ ButtonRow {
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

        +++ ButtonRow {
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

        +++ ButtonRow {
            $0.tag = "actions"
            $0.title = "Actions"
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "actions"
                return view
                }, onDismiss: { vc in
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
            }.onCellSelection { _, row in
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
            }

        +++ Section(header: "Developer Options", footer: "Don't use these if you don't know what you are doing!") {
            $0.hidden = Condition(booleanLiteral: (Current.appConfiguration.rawValue > 1))
            $0.tag = "developerOptions"
        }
        <<< ButtonRow {
                $0.title = "Copy Realm from group to container"
            }.onCellSelection { _, _ in
                let appGroupRealmPath = Current.realm().configuration.fileURL!
                let containerRealmPath = Realm.Configuration.defaultConfiguration.fileURL!

                print("Would copy from", appGroupRealmPath, "to", containerRealmPath)

                if FileManager.default.fileExists(atPath: containerRealmPath.path) {
                    do {
                        _ = try FileManager.default.removeItem(at: containerRealmPath)
                    } catch let error {
                        print("error occurred, here are the details:\n \(error)")
                    }
                }

                do {
                    _ = try FileManager.default.copyItem(at: appGroupRealmPath, to: containerRealmPath)
                } catch let error as NSError {
                    // Catch fires here, with an NSError being thrown
                    print("error occurred, here are the details:\n \(error)")
                }

                let msg = "Copied Realm from \(appGroupRealmPath) to \(containerRealmPath)"

                let alert = UIAlertController(title: "Copied Realm",
                                              message: msg,
                                              preferredStyle: UIAlertController.Style.alert)

                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

                self.present(alert, animated: true, completion: nil)
            }
        <<< ButtonRow {
                $0.title = "Import legacy push settings"
            }.onCellSelection {_, _ in
                MigratePushSettingsToLocal()
        }
        <<< ButtonRow {
            $0.title = "Test Critical Alerts"
            }.onCellSelection {_, _ in
                let content = UNMutableNotificationContent()
                content.title = "Critical Alerts Test"
                content.body = "This is a critical alert"
                if #available(iOS 12.0, *) {
                    content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1)
                }

                let notificationRequest =
                    UNNotificationRequest.init(identifier: "criticalAlertTest",
                                               content: content, trigger: nil)
                UNUserNotificationCenter.current().add(notificationRequest)
        }
        <<< ButtonRow {
            $0.title = "Print Watch contexts to log"
        }.onCellSelection { _, _ in
            print("Most recently received context", Communicator.shared.mostRecentlyReceievedContext.content)
            print("Most recently sent context", Communicator.shared.mostRecentlySentContext.content)
        }
        <<< ButtonRow {
            $0.title = "Show map content extension"
        }.onCellSelection { _, _ in
            self.showMapContentExtension()
        }
        <<< ButtonRow {
            $0.title = "Show camera content extension"
            }.onCellSelection { _, _ in
                self.showCameraContentExtension()
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

            let needsPass = discoveryInfo.RequiresPassword ? " - "+L10n.Settings.DiscoverySection.requiresPassword : ""
            var url = "\(discoveryInfo.BaseURL!.host!)"
            if let port = discoveryInfo.BaseURL!.port {
                url = "\(discoveryInfo.BaseURL!.host!):\(port)"
            }
            // swiftlint:disable:next line_length
            let detailTextLabel = "\(url) - \(discoveryInfo.Version) - \(discoveryInfo.BaseURL!.scheme!.uppercased()) \(needsPass)"
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
                            let apiPasswordRow: PasswordRow = self.form.rowBy(tag: "apiPassword")!
                            apiPasswordRow.value = ""
                            apiPasswordRow.hidden = Condition(booleanLiteral: !self.useLegacyAuth ||
                                !discoveryInfo.RequiresPassword)
                            apiPasswordRow.evaluateHidden()
                            if discoveryInfo.RequiresPassword {
                                apiPasswordRow.add(rule: RuleRequired())
                            } else {
                                apiPasswordRow.removeAllRules()
                            }
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
        let iosComponentLoadedRow: LabelRow = self.form.rowBy(tag: "iosComponentLoaded")!
        let api = HomeAssistantAPI.authenticatedAPI()
        iosComponentLoadedRow.value = api?.iosComponentLoaded ?? false ? "✔️" : "✖️"
        iosComponentLoadedRow.updateCell()
        let deviceTrackerComponentLoadedRow: LabelRow = self.form.rowBy(tag: "deviceTrackerComponentLoaded")!
        deviceTrackerComponentLoadedRow.value = api?.deviceTrackerComponentLoaded ?? false ? "✔️" : "✖️"
        deviceTrackerComponentLoadedRow.updateCell()
        let notifyPlatformLoadedRow: LabelRow = self.form.rowBy(tag: "notifyPlatformLoaded")!
        notifyPlatformLoadedRow.value = api?.iosNotifyPlatformLoaded ?? false ? "✔️" : "✖️"
        notifyPlatformLoadedRow.updateCell()
    }

    func ResetApp() {
        print("Resetting app!")
        resetStores()
        let bundleId = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: bundleId)
        UserDefaults.standard.synchronize()
        prefs.removePersistentDomain(forName: bundleId)
        prefs.synchronize()
        let urlRow: URLRow = self.form.rowBy(tag: "baseURL")!
        urlRow.value = nil
        urlRow.updateCell()
        let apiPasswordRow: PasswordRow = self.form.rowBy(tag: "apiPassword")!
        apiPasswordRow.value = ""
        apiPasswordRow.updateCell()
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
        print("Connection error!", error)
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
    }

    /// Resolves to the connection info used to connect. As a side effect, the successful tokenInfo is stored.
    private func confirmConnection(with connectionInfo: ConnectionInfo) -> Promise<ConnectionInfo> {
        let tryExistingCredentials: () -> Promise<ConfigResponse> = {
            if let existingTokenInfo = self.tokenInfo {
                let api = HomeAssistantAPI(connectionInfo: connectionInfo,
                                           authenticationMethod: .modern(tokenInfo: existingTokenInfo))
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
            print("Attempting browser auth to: \(connectionInfo.activeURL)")
            return firstly {
                self.authenticationController.authenticateWithBrowser(at: connectionInfo.activeURL)
            }.then { (code: String) -> Promise<String> in
                print("Browser auth succeeded, getting token")
                let tokenManager = TokenManager(connectionInfo: connectionInfo, tokenInfo: nil)
                return tokenManager.initialTokenWithCode(code)
            }.then { _ -> Promise<ConnectionInfo> in
                print("Token acquired")
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
            return false
        }

        if !self.useLegacyAuth {
            _ = firstly {
                    self.confirmConnection(with: connectionInfo)
                }.then { confirmedConnectionInfo -> Promise<ConfigResponse> in
                    // At this point we are authenticated with modern auth. Clear legacy password.
                    print("Confirmed connection to server: " + connectionInfo.activeURL.absoluteString)
                    let keychain = Keychain(service: Bundle.main.bundleIdentifier!)
                    keychain["apiPassword"] = nil
                    Current.settingsStore.connectionInfo = confirmedConnectionInfo
                    guard let tokenInfo = Current.settingsStore.tokenInfo else {
                        print("No token available when we think there should be")
                        throw SettingsError.configurationFailed
                    }

                    let api = HomeAssistantAPI(connectionInfo: confirmedConnectionInfo,
                                               authenticationMethod: .modern(tokenInfo: tokenInfo))
                    Current.updateWith(authenticatedAPI: api)
                    return api.Connect()
                }.done { config in
                    print("Getting current configuration successful. Updating UI")
                    self.configureUIWith(configResponse: config)
                }.catch { error in
                    self.handleConnectionError(error)
            }
        } else {
            let api = HomeAssistantAPI(connectionInfo: connectionInfo,
                                       authenticationMethod: .legacy(apiPassword: self.legacyPassword))

            api.Connect().done { config in
                /// Connected with legacy auth. Store credentials.
                Current.settingsStore.connectionInfo = connectionInfo
                if let password = self.legacyPassword {
                    keychain["apiPassword"] = password
                }
                Current.updateWith(authenticatedAPI: api)
                self.configureUIWith(configResponse: config)
            }.catch { error in
                    self.handleConnectionError(error)
            }
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
        print("Connected!")
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
            print("shake!")
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
                }
                return
            }
            shakeCount += 1
        }
    }

    func showMapContentExtension() {
        let content = UNMutableNotificationContent()
        content.title = "Roommate has arrived at home"
        content.subtitle = "Robbie has arrived at home."
        content.body = "Eddie, Katie and Robbie are home."
        content.sound = .default
        content.userInfo = ["homeassistant": ["latitude": "40.785091", "longitude": "-73.968285"]]
        content.categoryIdentifier = "map"

        let notificationRequest =
            UNNotificationRequest.init(identifier: "mapContentExtension",
                                       content: content, trigger: nil)
        UNUserNotificationCenter.current().add(notificationRequest)
    }

    func showCameraContentExtension() {
        let content = UNMutableNotificationContent()
        content.title = "Motion detected"
        content.body = "Motion has been detected outside"
        content.sound = .default
        content.userInfo = ["entity_id": "camera.demo_camera"]
        content.categoryIdentifier = "camera"

        let notificationRequest =
            UNNotificationRequest.init(identifier: "cameraContentExtension",
                                       content: content, trigger: nil)
        UNUserNotificationCenter.current().add(notificationRequest)
    }

    @objc func PermissionDidChange(_ notification: Notification) {
        if let userInfo = (notification as Notification).userInfo as? [String: Any] {
            if let locationChange = userInfo["location"] as? Bool {
                print("Location granted?", locationChange)

                DispatchQueue.main.async {
                    let enableLocationRow: ButtonRow = self.form.rowBy(tag: "enableLocation")!
                    enableLocationRow.hidden = Condition(booleanLiteral: locationChange)
                    enableLocationRow.updateCell()
                    enableLocationRow.evaluateHidden()
                    let locationSettingsRow: ButtonRow = self.form.rowBy(tag: "locationSettings")!
                    locationSettingsRow.hidden = Condition(booleanLiteral: !locationChange)
                    locationSettingsRow.updateCell()
                    locationSettingsRow.evaluateHidden()
                    let deviceTrackerComponentLoadedRow: LabelRow = self.form.rowBy(
                        tag: "deviceTrackerComponentLoaded")!
                    deviceTrackerComponentLoadedRow.hidden = Condition(booleanLiteral: !locationChange)
                    deviceTrackerComponentLoadedRow.evaluateHidden()
                    deviceTrackerComponentLoadedRow.updateCell()
                    self.tableView.reloadData()
                    if prefs.bool(forKey: "locationUpdateOnZone") == false {
                        Current.syncMonitoredRegions?()
                    }
                }
            }
            if let notificationsChange = userInfo["notifications"] as? Bool {
                print("Notifications granted?", notificationsChange)

                DispatchQueue.main.async {
                    let enableNotificationsRow: ButtonRow = self.form.rowBy(tag: "enableNotifications")!
                    enableNotificationsRow.hidden = Condition(booleanLiteral: notificationsChange)
                    enableNotificationsRow.updateCell()
                    enableNotificationsRow.evaluateHidden()
                    let settingsRow: ButtonRow = self.form.rowBy(tag: "notificationSettings")!
                    settingsRow.hidden = Condition(booleanLiteral: !notificationsChange)
                    settingsRow.evaluateHidden()
                    let loadedRow: LabelRow = self.form.rowBy(tag: "notifyPlatformLoaded")!
                    loadedRow.hidden = Condition(booleanLiteral: !notificationsChange)
                    loadedRow.evaluateHidden()
                    self.tableView.reloadData()
                }
            }
        }
    }
}

protocol ConnectionInfoChangedDelegate: class {
    func userReconnected()
}
