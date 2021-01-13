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
                $0.displayValueFor = { _ in Current.settingsStore.connectionInfo?.activeURLType.description }
            }

            <<< ButtonRowWithPresent<ConnectionURLViewController> { row in
                row.cellStyle = .value1
                row.title = L10n.Settings.ConnectionSection.InternalBaseUrl.title
                row.displayValueFor = { _ in Current.settingsStore.connectionInfo?.internalURL?.absoluteString }
                row.presentationMode = .show(controllerProvider: .callback(builder: {
                    ConnectionURLViewController(urlType: .internal, row: row)
                }), onDismiss: { [navigationController] _ in
                    navigationController?.popViewController(animated: true)
                })

                row.evaluateHidden()
            }

            <<< ButtonRowWithPresent<ConnectionURLViewController> { row in
                row.cellStyle = .value1
                row.title = L10n.Settings.ConnectionSection.ExternalBaseUrl.title
                row.displayValueFor = { _ in
                    if let connectionInfo = Current.settingsStore.connectionInfo {
                        if connectionInfo.useCloud && connectionInfo.canUseCloud {
                            return L10n.Settings.ConnectionSection.HomeAssistantCloud.title
                        } else {
                            return Current.settingsStore.connectionInfo?.externalURL?.absoluteString
                        }
                    } else {
                        return nil
                    }
                }
                row.presentationMode = .show(controllerProvider: .callback(builder: {
                    ConnectionURLViewController(urlType: .external, row: row)
                }), onDismiss: { [navigationController] _ in
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
        DispatchQueue.main.async { [self] in
            form.allRows.forEach { $0.updateCell() }
        }
    }
}
