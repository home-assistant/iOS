import CoreLocation
import Eureka
import Foundation
import PromiseKit
import Shared

final class ConnectionURLViewController: HAFormViewController, TypedRowControllerType {
    typealias RowValue = ConnectionURLViewController
    var row: RowOf<RowValue>!
    var onDismissCallback: ((UIViewController) -> Void)?
    let urlType: ConnectionInfo.URLType
    let server: Server

    init(server: Server, urlType: ConnectionInfo.URLType, row: RowOf<RowValue>) {
        self.server = server
        self.urlType = urlType
        self.row = row

        super.init()

        self.title = urlType.description

        if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }
    }

    enum SaveError: LocalizedError {
        case lastURL
        case validation([ValidationError])

        var errorDescription: String? {
            switch self {
            case .lastURL: return L10n.Settings.ConnectionSection.Errors.cannotRemoveLastUrl
            case let .validation(errors): return errors.map(\.msg).joined(separator: "\n")
            }
        }

        var isFinal: Bool {
            switch self {
            case .lastURL: return true
            case .validation: return true
            }
        }
    }

    private func check(url: URL?, useCloud: Bool?, validationErrors: [ValidationError]) throws {
        if !validationErrors.isEmpty {
            throw SaveError.validation(validationErrors)
        }

        if url == nil {
            let existingInfo = server.info.connection
            let other: ConnectionInfo.URLType = urlType == .internal ? .external : .internal
            if existingInfo.address(for: other) == nil,
               useCloud == false || (useCloud == nil && !existingInfo.useCloud) {
                throw SaveError.lastURL
            }
        }
    }

    @objc private func cancel() {
        onDismissCallback?(self)
    }

    @objc private func save() {
        let givenURL = (form.rowBy(tag: RowTag.url.rawValue) as? URLRow)?.value
        let useCloud = (form.rowBy(tag: RowTag.useCloud.rawValue) as? SwitchRow)?.value
        let localPush = (form.rowBy(tag: RowTag.localPush.rawValue) as? SwitchRow)?.value

        func commit() {
            server.update { info in
                info.connection.set(address: givenURL, for: urlType)

                if let useCloud = useCloud {
                    info.connection.useCloud = useCloud
                }

                if let localPush = localPush {
                    info.connection.isLocalPushEnabled = localPush
                }

                if let section = form.sectionBy(tag: RowTag.ssids.rawValue) as? MultivaluedSection {
                    info.connection.internalSSIDs = section.allRows
                        .compactMap { $0 as? TextRow }
                        .compactMap(\.value)
                        .filter { !$0.isEmpty }
                }

                if let section = form.sectionBy(tag: RowTag.hardwareAddresses.rawValue) as? MultivaluedSection {
                    info.connection.internalHardwareAddresses = section.allRows
                        .compactMap { $0 as? TextRow }
                        .compactMap(\.value)
                        .map { $0.lowercased() }
                        .filter { !$0.isEmpty }
                }
            }

            onDismissCallback?(self)
        }

        updateNavigationItems(isChecking: true)

        firstly { () -> Promise<Void> in
            try check(url: givenURL, useCloud: useCloud, validationErrors: form.validate())

            if useCloud == true, let url = server.info.connection.address(for: .remoteUI) {
                return Current.webhooks.sendTest(server: server, baseURL: url)
            }

            if let givenURL = givenURL, useCloud != true {
                return Current.webhooks.sendTest(server: server, baseURL: givenURL)
            }

            return .value(())
        }.ensure {
            self.updateNavigationItems(isChecking: false)
        }.done {
            commit()
        }.catch { error in
            let alert = UIAlertController(
                title: L10n.Settings.ConnectionSection.ValidateError.title,
                message: error.localizedDescription,
                preferredStyle: .alert
            )

            let canCommit: Bool

            if let error = error as? SaveError {
                canCommit = !error.isFinal
            } else {
                canCommit = true
            }

            if canCommit {
                alert.addAction(UIAlertAction(
                    title: L10n.Settings.ConnectionSection.ValidateError.useAnyway,
                    style: .default,
                    handler: { _ in commit() }
                ))
            }

            alert.addAction(UIAlertAction(
                title: L10n.Settings.ConnectionSection.ValidateError.editUrl,
                style: .cancel,
                handler: nil
            ))
            self.present(alert, animated: true, completion: nil)
        }
    }

    fileprivate enum RowTag: String {
        case url
        case ssids
        case hardwareAddresses
        case useCloud
        case localPush
    }

    private func updateNavigationItems(isChecking: Bool) {
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel)),
        ]

        if isChecking {
            let activityIndicator: UIActivityIndicatorView

            if #available(iOS 13, *) {
                activityIndicator = .init(style: .medium)
            } else {
                activityIndicator = .init(style: .gray)
            }

            activityIndicator.startAnimating()

            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(customView: activityIndicator),
            ]
        } else {
            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save)),
            ]
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateNavigationItems(isChecking: false)

        if urlType.isAffectedByCloud, server.info.connection.canUseCloud {
            form +++ SwitchRow {
                $0.title = L10n.Settings.ConnectionSection.HomeAssistantCloud.title
                $0.tag = RowTag.useCloud.rawValue
                $0.value = server.info.connection.useCloud
            }
        }

        form +++ Section()
            <<< URLRow(RowTag.url.rawValue) {
                $0.value = server.info.connection.address(for: urlType)
                $0.hidden = .function([RowTag.useCloud.rawValue], { form in
                    if let row = form.rowBy(tag: RowTag.useCloud.rawValue) as? SwitchRow {
                        // if cloud's around, hide when it's turned on
                        return row.value == true
                    } else {
                        // never hide if cloud isn't around
                        return false
                    }
                })
                $0.placeholder = { () -> String? in
                    switch urlType {
                    case .internal: return L10n.Settings.ConnectionSection.InternalBaseUrl.placeholder
                    case .external: return L10n.Settings.ConnectionSection.ExternalBaseUrl.placeholder
                    case .remoteUI: return nil
                    }
                }()
            }

            <<< InfoLabelRow {
                $0.title = L10n.Settings.ConnectionSection.cloudOverridesExternal
                $0.hidden = .function([RowTag.useCloud.rawValue], { form in
                    if let row = form.rowBy(tag: RowTag.useCloud.rawValue) as? SwitchRow {
                        // this is effectively the visual replacement for the external url, so show when cloud is on
                        return row.value == false
                    } else {
                        // always hide if we're not offering the cloud option
                        return true
                    }
                })
            }

        if urlType.isAffectedBySSID {
            form +++ locationPermissionSection()

            form +++ MultivaluedSection(
                tag: .ssids,
                header: L10n.Settings.ConnectionSection.InternalUrlSsids.header,
                footer: L10n.Settings.ConnectionSection.InternalUrlSsids.footer,
                addNewLabel: L10n.Settings.ConnectionSection.InternalUrlSsids.addNewSsid,
                placeholder: L10n.Settings.ConnectionSection.InternalUrlSsids.placeholder,
                currentValue: Current.connectivity.currentWiFiSSID,
                existingValues: server.info.connection.internalSSIDs ?? [],
                valueRules: RuleSet<String>()
            )
        }

        if urlType.isAffectedByHardwareAddress {
            var rules = RuleSet<String>()
            rules.add(rule: RuleRegExp(
                regExpr: "^[a-zA-Z0-9]{2}\\:[a-zA-Z0-9]{2}\\:[a-zA-Z0-9]{2}\\:[a-zA-Z0-9]{2}\\:[a-zA-Z0-9]{2}\\:[a-zA-Z0-9]{2}$",
                allowsEmpty: true,
                msg: L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.invalid,
                id: nil
            ))

            form +++ MultivaluedSection(
                tag: .hardwareAddresses,
                header: L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.header,
                footer: L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.footer,
                addNewLabel: L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.addNewSsid,
                placeholder: "aa:bb:cc:dd:ee:ff",
                currentValue: Current.connectivity.currentNetworkHardwareAddress,
                existingValues: server.info.connection.internalHardwareAddresses ?? [],
                valueRules: rules
            )
        }

        if urlType.hasLocalPush {
            form +++ Section(
                footer: L10n.Settings.ConnectionSection.localPushDescription
            ) <<< SwitchRow(RowTag.localPush.rawValue) {
                $0.title = L10n.SettingsDetails.Notifications.LocalPush.title
                $0.value = server.info.connection.isLocalPushEnabled
            } <<< LearnMoreButtonRow {
                $0.onCellSelection { cell, _ in
                    openURLInBrowser(
                        URL(string: "https://companion.home-assistant.io/app/ios/local-push")!,
                        cell.formViewController()
                    )
                }
            }
        }
    }

    private func locationPermissionSection() -> Section {
        class PermissionWatchingDelegate: NSObject, CLLocationManagerDelegate {
            let section: Section

            init(section: Section) {
                self.section = section
            }

            func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
                section.evaluateHidden()
            }

            func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
                section.evaluateHidden()
            }
        }

        let section = Section()
        var locationManager: CLLocationManager? = CLLocationManager()
        var permissionDelegate: PermissionWatchingDelegate? = PermissionWatchingDelegate(section: section)
        locationManager?.delegate = permissionDelegate

        section.hidden = .function([], { _ in
            if #available(iOS 14, *), let locationManager = locationManager {
                return locationManager.authorizationStatus == .authorizedAlways &&
                    locationManager.accuracyAuthorization == .fullAccuracy
            } else {
                return CLLocationManager.authorizationStatus() == .authorizedAlways
            }
        })
        section.evaluateHidden()

        after(life: self).done {
            // we're keeping these lifetimes around longer so they update
            locationManager = nil
            permissionDelegate = nil
        }

        section <<< InfoLabelRow {
            if #available(iOS 14, *) {
                $0.title = L10n.Settings.ConnectionSection.ssidPermissionAndAccuracyMessage
            } else {
                $0.title = L10n.Settings.ConnectionSection.ssidPermissionMessage
            }

            $0.displayType = .important

            $0.cellUpdate { cell, _ in
                cell.accessibilityTraits.insert(.button)
                cell.selectionStyle = .default
            }

            $0.onCellSelection { _, _ in
                if CLLocationManager.authorizationStatus() == .notDetermined {
                    locationManager?.requestAlwaysAuthorization()
                } else {
                    UIApplication.shared.openSettings(destination: .location)
                }
            }
        }

        return section
    }
}

private extension MultivaluedSection {
    convenience init(
        tag: ConnectionURLViewController.RowTag,
        header: String,
        footer: String,
        addNewLabel: String,
        placeholder: String,
        currentValue: @escaping () -> String?,
        existingValues: [String],
        valueRules: RuleSet<String>
    ) {
        self.init(
            multivaluedOptions: [.Insert, .Delete],
            header: header,
            footer: footer
        ) { section in
            section.tag = tag.rawValue
            section.addButtonProvider = { _ in
                ButtonRow {
                    $0.title = addNewLabel
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .natural
                    cell.selectionStyle = .default
                }
            }

            func row(for value: String?) -> TextRow {
                TextRow {
                    $0.placeholder = placeholder
                    $0.value = value
                    $0.add(ruleSet: valueRules)
                }
            }

            section.multivaluedRowToInsertAt = { _ in
                let current = currentValue()

                if section.allRows.contains(where: { ($0 as? TextRow)?.value == current }) {
                    return row(for: nil)
                } else {
                    return row(for: current)
                }
            }

            section.append(contentsOf: existingValues.map { row(for: $0) })
        }
    }
}
