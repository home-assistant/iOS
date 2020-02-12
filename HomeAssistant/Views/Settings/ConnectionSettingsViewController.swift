//
//  ConnectionSettingsViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/20/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import Shared
import PromiseKit
import Alamofire

class ConnectionSettingsViewController: FormViewController, RowControllerType {

    public var onDismissCallback: ((UIViewController) -> Void)?

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L10n.Settings.ConnectionSection.header

        NotificationCenter.default.addObserver(self, selector: #selector(ActiveURLTypeChanged(_:)),
                                               // swiftlint:disable:next line_length
                                               name: NSNotification.Name(rawValue: "connectioninfo.activeurltype_changed"),
                                               object: nil)

        form
            +++ Section(header: L10n.Settings.StatusSection.header, footer: "") {
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

            <<< LabelRow("currentUser") {
                $0.title = L10n.Settings.ConnectionSection.loggedInAs
                $0.value = Current.settingsStore.authenticatedUser?.Name
            }

            /* <<< ButtonRow("logout") {
                $0.title = L10n.Settings.ConnectionSection.logOut
            }.cellUpdate { cell, _ in
                cell.textLabel?.textColor = .red
            } */

            +++ Section(L10n.Settings.ConnectionSection.details)
            <<< LabelRow("connectionPath") {
                $0.title = L10n.Settings.ConnectionSection.connectingVia
                $0.value = Current.settingsStore.connectionInfo?.activeURLType.description
            }

            <<< LabelRow("cloudAvailable") {
                $0.title = L10n.Settings.ConnectionSection.HomeAssistantCloud.title
                $0.value = Current.settingsStore.connectionInfo?.remoteUIURL != nil ? "✔️" : "✖️"
                $0.hidden = Condition(booleanLiteral: Current.settingsStore.connectionInfo?.remoteUIURL == nil)
            }.onCellSelection { cell, _ in
                guard let url = Current.settingsStore.connectionInfo?.remoteUIURL else { return }
                let alert = UIAlertController(title: nil, message: url.absoluteString, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                alert.popoverPresentationController?.sourceView = cell.contentView
            }

            <<< SwitchRow("useCloud") {
                $0.title = "Connect via Cloud"
                $0.value = Current.settingsStore.connectionInfo?.useCloud
                $0.hidden = Condition(booleanLiteral: Current.settingsStore.connectionInfo?.remoteUIURL == nil)
            }.onChange { row in
                guard let value = row.value else { return }
                if value == false {
                    guard let externalURLRow = self.form.rowBy(tag: "externalURL") as? URLRow else { return }

                    if externalURLRow.value == nil {
                        row.value = true
                        row.updateCell()

                        let alert = UIAlertController(title: L10n.errorLabel,
                                                      message: L10n.Settings.ConnectionSection.Errors.cantDisableCloud,
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        alert.popoverPresentationController?.sourceView = row.cell.contentView
                        return
                    }
                }
                Current.settingsStore.connectionInfo?.useCloud = value
            }

            <<< URLRow("internalURL") {
                $0.title = L10n.Settings.ConnectionSection.InternalBaseUrl.title
                $0.value = Current.settingsStore.connectionInfo?.internalURL
                $0.placeholder = L10n.Settings.ConnectionSection.InternalBaseUrl.placeholder
            }.onCellHighlightChanged { (cell, row) in
                if !row.isHighlighted {
                    guard let newURL = row.value else {
                        Current.settingsStore.connectionInfo?.setAddress(nil, .internal)
                        return
                    }

                    if let host = newURL.host, host.contains("nabu.casa") {
                        let alert = UIAlertController(title: L10n.errorLabel, message: L10n.Errors.noRemoteUiUrl,
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        alert.popoverPresentationController?.sourceView = cell.contentView
                        return
                    }
                    self.confirmURL(newURL).done { _ in
                        Current.settingsStore.connectionInfo?.setAddress(newURL, .internal)
                    }.catch { error in
                        row.value = Current.settingsStore.connectionInfo?.internalURL
                        row.updateCell()
                        let alert = UIAlertController(title: L10n.errorLabel, message: error.localizedDescription,
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        alert.popoverPresentationController?.sourceView = cell.contentView
                    }
                }
            }

            <<< URLRow("externalURL") {
                $0.title = L10n.Settings.ConnectionSection.ExternalBaseUrl.title
                $0.value = Current.settingsStore.connectionInfo?.externalURL
                $0.placeholder = L10n.Settings.ConnectionSection.ExternalBaseUrl.placeholder
            }.onCellHighlightChanged { (cell, row) in
                if !row.isHighlighted {
                    guard let newURL = row.value else {

                        if Current.settingsStore.connectionInfo?.remoteUIURL != nil {
                            Current.settingsStore.connectionInfo?.setAddress(nil, .external)
                            guard let useCloudRow = self.form.rowBy(tag: "useCloud") as? SwitchRow else { return }
                            useCloudRow.value = true
                            useCloudRow.updateCell()
                        } else {
                            let alert = UIAlertController(title: L10n.errorLabel,
                                                          // swiftlint:disable:next line_length
                                                          message: L10n.Settings.ConnectionSection.Errors.noCloudExternalUrlRequired,
                                                          preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                            alert.popoverPresentationController?.sourceView = cell.contentView
                        }
                        return
                    }
                    if let host = newURL.host, host.contains("nabu.casa") {
                        let alert = UIAlertController(title: L10n.errorLabel, message: L10n.Errors.noRemoteUiUrl,
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        alert.popoverPresentationController?.sourceView = cell.contentView
                    }
                    self.confirmURL(newURL).done { _ in
                        Current.settingsStore.connectionInfo?.setAddress(newURL, .external)
                    }.catch { error in
                        row.value = Current.settingsStore.connectionInfo?.externalURL
                        row.updateCell()
                        let alert = UIAlertController(title: L10n.errorLabel, message: error.localizedDescription,
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        alert.popoverPresentationController?.sourceView = cell.contentView
                    }
                }
            }

            +++ MultivaluedSection(multivaluedOptions: [.Insert, .Delete],
                                   header: L10n.Settings.ConnectionSection.InternalUrlSsids.header,
                                   footer: L10n.Settings.ConnectionSection.InternalUrlSsids.footer) {
                $0.tag = "internalSSIDs"
                $0.addButtonProvider = { _ in
                    return ButtonRow {
                        $0.title = L10n.Settings.ConnectionSection.InternalUrlSsids.addNewSsid
                    }.cellUpdate { cell, _ in
                        cell.textLabel?.textAlignment = .left
                    }
                }

                $0.multivaluedRowToInsertAt = { index in
                    return TextRow {
                        $0.placeholder = L10n.Settings.ConnectionSection.InternalUrlSsids.placeholder
                        $0.value = self.currentSSID
                    }.onCellHighlightChanged { self.addSSID($1.value) }
                }

                $0.append(contentsOf: Current.settingsStore.connectionInfo?.internalSSIDs?.map { ssid in
                    return TextRow { $0.value = ssid }.onCellHighlightChanged { self.addSSID($1.value) }
                } ?? [TextRow]())
            }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Detect when your view controller is popped and invoke the callback
        if !isMovingToParent {
            onDismissCallback?(self)
        }
    }

    /// currentSSID returns the currently connected SSID if it hasn't been stored already or if no SSIDs are stored.
    var currentSSID: String? {
        // First, ensure we are connected to a network
        guard let currentSSID = ConnectionInfo.CurrentWiFiSSID else { return nil }

        // Next, ensure SSIDs have been previously stored. If not, then we should show the row
        guard let storedSSIDs = Current.settingsStore.connectionInfo?.internalSSIDs else { return currentSSID }

        // Finally, check to see if the current SSID is stored in the existing SSID list
        guard storedSSIDs.contains(currentSSID) == false else { return currentSSID }

        // Okay, the SSID must have been in the list so lets return nothing so the row wont appear
        return currentSSID
    }

    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at indexes: [IndexPath]) {
        super.rowsHaveBeenRemoved(rows, at: indexes)
        let values = rows.compactMap { $0.baseValue as? String }
        Current.settingsStore.connectionInfo?.internalSSIDs?.removeAll { values.contains($0) }
    }

    func addSSID(_ ssid: String?) {
        guard let value = ssid else { return }
        guard let ssids = Current.settingsStore.connectionInfo?.internalSSIDs else { return }
        if !ssids.contains(value) {
            Current.settingsStore.connectionInfo?.internalSSIDs?.append(value)
        }
    }
    
    func confirmURL(_ connectionURL: URL) -> Promise<Void> {
        return Promise { seal in
            guard let webhookID = Current.settingsStore.connectionInfo?.webhookID else {
                seal.reject(HomeAssistantAPI.APIError.cantBuildURL)
                return
            }
            let url = connectionURL.appendingPathComponent("api/webhook/\(webhookID)")
            Current.Log.verbose("Confirming URL at \(url)")

            Alamofire.request(url, method: .post, parameters: WebhookRequest(type: "get_config", data: [:]).toJSON(),
                              encoding: JSONEncoding.default).validate().responseJSON { resp in
                switch resp.result {
                case .success:
                    seal.fulfill_()
                case .failure(let error):
                    Current.Log.error("Received error \(error)")
                    seal.reject(error)
                }
            }
        }
    }

    @objc func ActiveURLTypeChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: ConnectionInfo.URLType],
            let newType = userInfo["newType"],
            let pathRow = self.form.rowBy(tag: "connectionPath") as? LabelRow else { return }
        pathRow.value = newType.description
        pathRow.updateCell()
    }
}
