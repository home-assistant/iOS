import Alamofire
import Eureka
import ObjectMapper
import PromiseKit
import Shared
import UIKit
import HAKit

class ConnectionSettingsViewController: FormViewController, RowControllerType {
    public var onDismissCallback: ((UIViewController) -> Void)?

    let connection: HAConnection

    init(connection: HAConnection) {
        self.connection = connection

        if #available(iOS 13, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var tokens: [HACancellable] = []

    deinit {
        tokens.forEach { $0.cancel() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.Settings.ConnectionSection.header

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

            <<< WebSocketStatusRow()

            <<< LabelRow { row in
                row.title = L10n.Settings.ConnectionSection.loggedInAs

                tokens.append(connection.caches.user.subscribe { _, user in
                    row.value = user.name
                    row.updateCell()
                })
            }

            +++ Section(L10n.Settings.ConnectionSection.details)
            <<< TextRow {
                $0.title = L10n.SettingsDetails.General.DeviceName.title
                $0.placeholder = Current.device.deviceName()
                $0.value = Current.settingsStore.overrideDeviceName
                $0.onChange { row in
                    Current.settingsStore.overrideDeviceName = row.value
                }
            }
            
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
                        if connectionInfo.useCloud, connectionInfo.canUseCloud {
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
