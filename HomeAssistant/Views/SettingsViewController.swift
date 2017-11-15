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
import Crashlytics
import SafariServices
import Alamofire
import KeychainAccess
import CoreLocation
import UserNotifications

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
class SettingsViewController: FormViewController, CLLocationManagerDelegate {

    weak var delegate: ConnectionInfoChangedDelegate?

    var doneButton: Bool = false

    var showErrorConnectingMessage = false
    var showErrorConnectingMessageError: Error?

    var baseURL: URL?
    var password: String?
    var deviceID: String?

    var configured = false

    let discovery = Bonjour()

    var locationManager: CLLocationManager = CLLocationManager()

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
        // Do any additional setup after loading the view, typically from a nib.

        self.locationManager.delegate = self

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

        if let baseURLString = keychain["baseURL"] {
            if let baseURL = URL(string: baseURLString) {
                self.baseURL = baseURL
                self.configured = true
            }
        }

        self.password = keychain["apiPassword"]

        self.deviceID = keychain["deviceID"]

        if showErrorConnectingMessage {
            let errDesc = (showErrorConnectingMessageError?.localizedDescription)!
            let alert = UIAlertController(title: L10n.Settings.ConnectionErrorNotification.title,
                                          message: L10n.Settings.ConnectionErrorNotification.message(errDesc),
                                          preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }

        let queue = DispatchQueue(label: "io.robbie.homeassistant", attributes: [])
        queue.async { () -> Void in
            self.discovery.stopDiscovery()
            self.discovery.stopPublish()

            self.discovery.startDiscovery()
            self.discovery.startPublish()
        }

        NotificationCenter.default.addObserver(self,
            selector: #selector(SettingsViewController.HomeAssistantDiscovered(_:)),
            name: NSNotification.Name(rawValue: "homeassistant.discovered"),
            object: nil)

        NotificationCenter.default.addObserver(self,
            selector: #selector(SettingsViewController.HomeAssistantUndiscovered(_:)),
            name: NSNotification.Name(rawValue: "homeassistant.undiscovered"),
            object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(SettingsViewController.Connected(_:)),
                                               name: NSNotification.Name(rawValue: "connected"),
                                               object: nil)

        form
            +++ Section(header: L10n.Settings.DiscoverySection.header, footer: "") {
                $0.tag = "discoveredInstances"
                $0.hidden = true
            }

            +++ Section(header: L10n.Settings.ConnectionSection.header, footer: "")
            <<< URLRow("baseURL") {
                $0.title = L10n.Settings.ConnectionSection.BaseUrl.title
                $0.value = self.baseURL
                $0.placeholder = "https://homeassistant.myhouse.com"
            }.onCellHighlightChanged({ (_, row) in
                if row.isHighlighted == false {
                    if let url = row.value {
                        let cleanUrl = HomeAssistantAPI.sharedInstance.CleanBaseURL(baseUrl: url)
                        if !cleanUrl.hasValidScheme {
                            let title = L10n.Settings.ConnectionSection.InvalidUrlSchemeNotification.title
                            let message = L10n.Settings.ConnectionSection.InvalidUrlSchemeNotification.message
                            let alert = UIAlertController(title: title, message: message,
                                                          preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertActionStyle.default,
                                                          handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        } else {
                            self.baseURL = cleanUrl.cleanedURL
                        }
                    }
                }
            })

            <<< PasswordRow("apiPassword") {
                    $0.title = L10n.Settings.ConnectionSection.ApiPasswordRow.title
                    $0.value = self.password
                    $0.placeholder = L10n.Settings.ConnectionSection.ApiPasswordRow.placeholder
                }.onChange { row in
                    self.password = row.value
                }.cellUpdate { cell, row in
                    if !row.isValid {
                        cell.titleLabel?.textColor = .red
                    }
                }

            <<< ButtonRow("connect") {
                    $0.title = L10n.Settings.ConnectionSection.SaveButton.title
                }.onCellSelection { _, _ in
                    if self.form.validate().count == 0 {
                        if let baseUrl = self.baseURL {
                            HomeAssistantAPI.sharedInstance.Setup(baseURLString: baseUrl.absoluteString,
                                                                  password: self.password, deviceID: self.deviceID)
                            HomeAssistantAPI.sharedInstance.Connect().then { config -> Void in
                                print("Connected!")
                                if let url = self.baseURL {
                                    keychain["baseURL"] = url.absoluteString
                                }
                                if let password = self.password {
                                    keychain["apiPassword"] = password
                                }
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
                            }.catch { error in
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
                                                              preferredStyle: UIAlertControllerStyle.alert)
                                alert.addAction(UIAlertAction(title: L10n.okLabel,
                                                              style: UIAlertActionStyle.default,
                                                              handler: nil))
                                self.present(alert, animated: true, completion: nil)
                            }

                        } else {
                            let errMsg = L10n.Settings.ConnectionError.InvalidUrl.message
                            let alert = UIAlertController(title: L10n.Settings.ConnectionError.InvalidUrl.title,
                                                          message: errMsg,
                                                          preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: L10n.okLabel,
                                                          style: UIAlertActionStyle.default,
                                                          handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
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
                $0.value = HomeAssistantAPI.sharedInstance.iosComponentLoaded ? "✔️" : "✖️"
            }
            <<< LabelRow("deviceTrackerComponentLoaded") {
                $0.title = L10n.Settings.StatusSection.DeviceTrackerComponentLoadedRow.title
                $0.value = HomeAssistantAPI.sharedInstance.deviceTrackerComponentLoaded ? "✔️" : "✖️"
                $0.hidden = Condition(booleanLiteral: HomeAssistantAPI.sharedInstance.locationEnabled == false)
            }
            <<< LabelRow("notifyPlatformLoaded") {
                $0.title = L10n.Settings.StatusSection.NotifyPlatformLoadedRow.title
                $0.value = HomeAssistantAPI.sharedInstance.iosNotifyPlatformLoaded ? "✔️" : "✖️"
                $0.hidden = Condition(booleanLiteral: HomeAssistantAPI.sharedInstance.notificationsEnabled == false)
            }

            +++ Section(header: "", footer: L10n.Settings.DeviceIdSection.footer)
            <<< TextRow("deviceId") {
                $0.title = L10n.Settings.DeviceIdSection.DeviceIdRow.title
                if let deviceID = self.deviceID {
                    $0.value = deviceID
                } else {
                    $0.value = HomeAssistantAPI.sharedInstance.deviceID
                }
                $0.cell.textField.autocapitalizationType = .none
                }.cellUpdate { _, row in
                    if row.isHighlighted == false {
                        if let deviceId = row.value {
                            HomeAssistantAPI.sharedInstance.deviceID = deviceId
                            self.deviceID = deviceId
                            keychain["deviceID"] = deviceId
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
                $0.hidden = Condition(booleanLiteral: HomeAssistantAPI.sharedInstance.locationEnabled)
            }.onCellSelection { _, _ in
                self.locationManager.requestAlwaysAuthorization()
            }

            <<< ButtonRow("locationSettings") {
                $0.title = L10n.Settings.DetailsSection.LocationSettingsRow.title
                $0.hidden = Condition(booleanLiteral: !HomeAssistantAPI.sharedInstance.locationEnabled)
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
                $0.hidden = Condition(booleanLiteral: HomeAssistantAPI.sharedInstance.notificationsEnabled)
                }.onCellSelection { _, row in
                    if #available(iOS 10, *) {
                        let center = UNUserNotificationCenter.current()
                        center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                            if error != nil {
                                let alert = UIAlertController(title: L10n.Settings.ConnectionSection.ErrorEnablingNotifications.title,
                                                              message: L10n.Settings.ConnectionSection.ErrorEnablingNotifications.message,
                                                              preferredStyle: UIAlertControllerStyle.alert)
                                alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertActionStyle.default,
                                                              handler: nil))
                                self.present(alert, animated: true, completion: nil)
                            } else {
                                print("Notifications Permissions finished!", granted)
                                prefs.setValue(granted, forKey: "notificationsEnabled")
                                prefs.synchronize()
                                if granted {
                                    HomeAssistantAPI.sharedInstance.setupPush()
                                    DispatchQueue.main.async(execute: {
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
                                    })
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async(execute: {
                            let setting = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
                            UIApplication.shared.registerUserNotificationSettings(setting)
                            UIApplication.shared.registerForRemoteNotifications()
                        })
                    }
            }

            <<< ButtonRow("notificationSettings") {
                $0.title = L10n.Settings.DetailsSection.NotificationSettingsRow.title
                $0.hidden = Condition(booleanLiteral: !HomeAssistantAPI.sharedInstance.notificationsEnabled)
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    let view = SettingsDetailViewController()
                    view.detailGroup = "notifications"
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
                                                  preferredStyle: UIAlertControllerStyle.alert)

                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

                    alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { (_) in
                        row.hidden = true
                        row.evaluateHidden()
                        self.ResetApp()
                    }))

                    self.present(alert, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func HomeAssistantDiscovered(_ notification: Notification) {
        let discoverySection: Section = self.form.sectionBy(tag: "discoveredInstances")!
        discoverySection.hidden = false
        discoverySection.evaluateHidden()
        if let userInfo = (notification as Notification).userInfo as? [String: Any] {
            let discoveryInfo = DiscoveryInfoResponse(JSON: userInfo)!
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
                            $0.cellStyle = UITableViewCellStyle.subtitle
                        }.cellUpdate { cell, _ in
                            cell.textLabel?.textColor = .black
                            cell.detailTextLabel?.text = detailTextLabel
                        }.onCellSelection({ _, _ in
                            self.baseURL = discoveryInfo.BaseURL
                            let urlRow: URLRow = self.form.rowBy(tag: "baseURL")!
                            urlRow.value = discoveryInfo.BaseURL
                            urlRow.updateCell()
                            let apiPasswordRow: PasswordRow = self.form.rowBy(tag: "apiPassword")!
                            apiPasswordRow.value = ""
                            apiPasswordRow.hidden = Condition(booleanLiteral: !discoveryInfo.RequiresPassword)
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
        iosComponentLoadedRow.value = HomeAssistantAPI.sharedInstance.iosComponentLoaded ? "✔️" : "✖️"
        iosComponentLoadedRow.updateCell()
        let deviceTrackerComponentLoadedRow: LabelRow = self.form.rowBy(tag: "deviceTrackerComponentLoaded")!
        deviceTrackerComponentLoadedRow.value = HomeAssistantAPI.sharedInstance.deviceTrackerComponentLoaded ? "✔️" : "✖️"
        deviceTrackerComponentLoadedRow.updateCell()
        let notifyPlatformLoadedRow: LabelRow = self.form.rowBy(tag: "notifyPlatformLoaded")!
        notifyPlatformLoadedRow.value = HomeAssistantAPI.sharedInstance.iosNotifyPlatformLoaded ? "✔️" : "✖️"
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
    }

    @objc func openAbout(_ sender: UIButton) {
        let aboutView = AboutViewController()

        let navController = UINavigationController(rootViewController: aboutView)
        self.show(navController, sender: nil)
        //        self.present(navController, animated: true, completion: nil)
    }

    @objc func closeSettings(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
            prefs.setValue(true, forKey: "locationEnabled")
            prefs.synchronize()
            let enableLocationRow: ButtonRow = self.form.rowBy(tag: "enableLocation")!
            enableLocationRow.hidden = true
            enableLocationRow.updateCell()
            enableLocationRow.evaluateHidden()
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
            HomeAssistantAPI.sharedInstance.setupZones()
            _ = HomeAssistantAPI.sharedInstance.sendOneshotLocation()
        }
    }
}

protocol ConnectionInfoChangedDelegate: class {
    func userReconnected()
}
