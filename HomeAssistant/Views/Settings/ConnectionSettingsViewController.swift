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

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

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
                $0.title = "Logged in as"
                $0.value = Current.settingsStore.authenticatedUser?.Name
            }

            +++ Section(L10n.Settings.ConnectionSection.details)
            <<< LabelRow("connectionPath") {
                $0.title = L10n.Settings.ConnectionSection.connectingVia
                $0.value = HomeAssistantAPI.authenticatedAPI()?.webhookHandler.activeURLType.description
            }

            <<< URLRow("externalURL") {
                $0.title = L10n.Settings.ConnectionSection.ExternalBaseUrl.title
                $0.value = Current.settingsStore.connectionInfo?.externalBaseURL
            }.onCellHighlightChanged { (cell, row) in
                if !row.isHighlighted {
                    guard let newURL = row.value else { return }
                    self.confirmURL(newURL).done { _ in
                        guard let connInfo = Current.settingsStore.connectionInfo else {
                            return
                        }
                        Current.settingsStore.connectionInfo = ConnectionInfo(baseURL: newURL,
                                                                              internalBaseURL: connInfo.internalBaseURL,
                                                                              internalSSIDs: connInfo.internalSSIDs)
                        }.catch { error in
                            row.value = Current.settingsStore.connectionInfo?.externalBaseURL
                            row.updateCell()
                            let alert = UIAlertController(title: L10n.errorLabel, message: error.localizedDescription,
                                                          preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                            alert.popoverPresentationController?.sourceView = cell.contentView
                    }
                }
            }

            <<< URLRow("internalURL") {
                $0.title = L10n.Settings.ConnectionSection.InternalBaseUrl.title
                $0.value = Current.settingsStore.connectionInfo?.internalBaseURL
            }.onCellHighlightChanged { (cell, row) in
                if !row.isHighlighted {
                    guard let newURL = row.value else { return }
                    self.confirmURL(newURL).done { _ in
                        guard let connInfo = Current.settingsStore.connectionInfo else {
                            return
                        }
                        Current.settingsStore.connectionInfo = ConnectionInfo(baseURL: connInfo.externalBaseURL,
                                                                              internalBaseURL: newURL,
                                                                              internalSSIDs: connInfo.internalSSIDs)
                    }.catch { error in
                        row.value = Current.settingsStore.connectionInfo?.internalBaseURL
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
                    }.onCellHighlightChanged { _, _ in self.storeSSIDs() }
                }

                $0.append(contentsOf: Current.settingsStore.connectionInfo?.internalSSIDs?.map { ssid in
                    return TextRow { $0.value = ssid }.onCellHighlightChanged { _, _ in self.storeSSIDs() }
                } ?? [TextRow]())
            }

            +++ Section(L10n.Settings.ConnectionSection.nabuCasaCloud)
            <<< LabelRow("cloudAvailable") {
                $0.title = L10n.Settings.ConnectionSection.cloudAvailable
                $0.value = HomeAssistantAPI.LoadedComponents.contains("cloud") ? "✔️" : "✖️"
            }

            <<< LabelRow("cloudhookAvailable") {
                $0.title = L10n.Settings.ConnectionSection.cloudhookAvailable
                $0.value = Current.settingsStore.cloudhookURL != nil ? "✔️" : "✖️"
            }

            <<< LabelRow("remoteUIAvailable") {
                $0.title = L10n.Settings.ConnectionSection.remoteUiAvailable
                $0.value = Current.settingsStore.remoteUIURL != nil ? "✔️" : "✖️"
            }

            +++ ButtonRow("logout") {
                $0.title = L10n.Settings.ConnectionSection.logOut
            }.cellUpdate { cell, _ in
                cell.textLabel?.textColor = .red
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
        self.storeSSIDs()
    }

    func storeSSIDs() {
        if let section = self.form.sectionBy(tag: "internalSSIDs") as? MultivaluedSection {
            let ssids = section.values().compactMap { $0 as? String }
            guard let connInfo = Current.settingsStore.connectionInfo else {
                return
            }
            Current.settingsStore.connectionInfo = ConnectionInfo(baseURL: connInfo.externalBaseURL,
                                                                  internalBaseURL: connInfo.internalBaseURL,
                                                                  internalSSIDs: ssids)
        }
    }

    func confirmURL(_ connectionURL: URL) -> Promise<Void> {
        return Promise { seal in
            let webhookID = Current.settingsStore.webhookID!
            let url = connectionURL.appendingPathComponent("api/webhook/\(webhookID)")
            Current.Log.verbose("Confirming URL at \(url)")

            Alamofire.request(url, method: .post, parameters: WebhookRequest(type: "get_config", data: [:]).toJSON(),
                              encoding: JSONEncoding.default).validate().responseJSON { resp in
                switch resp.result {
                case .success:
                    seal.fulfill_()
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
}
