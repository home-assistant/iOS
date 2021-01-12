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
import ObjectMapper

class ConnectionSettingsViewController: FormViewController, RowControllerType {

    public var onDismissCallback: ((UIViewController) -> Void)?

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L10n.Settings.ConnectionSection.header

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectionInfoDidChange(_:)),
            name: SettingsStore.connectionInfoDidChange,
            object: nil
        )

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
                alert.addAction(UIAlertAction(title: L10n.copyLabel, style: .default, handler: { _ in
                    UIPasteboard.general.url = url
                }))
                alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: nil))
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
                    if Current.settingsStore.connectionInfo?.externalURL == nil,
                        Current.settingsStore.connectionInfo?.internalURL == nil {
                        // no other url is available, can't allow turning it off
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

            <<< ButtonRowWithPresent<ConnectionURLViewController> { row in
                row.hidden = .function([], { _ in
                    ConnectionInfo.hasWiFi == false
                })

                row.cellStyle = .value1
                row.title = L10n.Settings.ConnectionSection.InternalBaseUrl.title
                row.displayValueFor = { _ in Current.settingsStore.connectionInfo?.internalURL?.absoluteString }
                row.presentationMode = .show(controllerProvider: .callback(builder: {
                    ConnectionURLViewController(urlType: .internal, row: row)
                }), onDismiss: { [navigationController] _ in
                    row.updateCell()
                    navigationController?.popViewController(animated: true)
                })

                row.evaluateHidden()
            }

            <<< ButtonRowWithPresent<ConnectionURLViewController> { row in
                row.cellStyle = .value1
                row.title = L10n.Settings.ConnectionSection.ExternalBaseUrl.title
                row.displayValueFor = { _ in Current.settingsStore.connectionInfo?.externalURL?.absoluteString }
                row.presentationMode = .show(controllerProvider: .callback(builder: {
                    ConnectionURLViewController(urlType: .external, row: row)
                }), onDismiss: { [navigationController] _ in
                    row.updateCell()
                    navigationController?.popViewController(animated: true)
                })
            }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Detect when your view controller is popped and invoke the callback
        if !isMovingToParent {
            onDismissCallback?(self)
        }
    }

    @objc func connectionInfoDidChange(_ notification: Notification) {
        guard let pathRow = self.form.rowBy(tag: "connectionPath") as? LabelRow else { return }
        pathRow.value = Current.settingsStore.connectionInfo?.activeURLType.description
        pathRow.updateCell()
    }
}
