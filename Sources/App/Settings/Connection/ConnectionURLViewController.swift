import Foundation
import Eureka
import Shared
import PromiseKit
import CoreLocation

final class ConnectionURLViewController: FormViewController, TypedRowControllerType {
    typealias RowValue = ConnectionURLViewController
    var row: RowOf<RowValue>!
    var onDismissCallback: ((UIViewController) -> Void)?
    let urlType: ConnectionInfo.URLType

    init(urlType: ConnectionInfo.URLType, row: RowOf<RowValue>) {
        self.urlType = urlType
        self.row = row

        if #available(iOS 13, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }

        self.title = urlType.description

        if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    enum SaveError: LocalizedError {
        case nabuCasa
        case lastURL

        var errorDescription: String? {
            switch self {
            case .nabuCasa: return L10n.Errors.noRemoteUiUrl
            case .lastURL: return L10n.Settings.ConnectionSection.Errors.cannotRemoveLastUrl
            }
        }

        var isFinal: Bool {
            switch self {
            case .nabuCasa: return true
            case .lastURL: return true
            }
        }
    }

    private func check(url: URL?) throws {
        if url?.host?.contains("nabu.casa") == true {
            throw SaveError.nabuCasa
        }

        if url == nil, let existingInfo = Current.settingsStore.connectionInfo {
            let other: ConnectionInfo.URLType = urlType == .internal ? .external : .internal
            if !existingInfo.useCloud, existingInfo.address(for: other) == nil {
                throw SaveError.lastURL
            }
        }
    }

    @objc private func cancel() {
        onDismissCallback?(self)
    }

    @objc private func save() {
        let givenURL = (form.rowBy(tag: RowTag.url.rawValue) as? URLRow)?.value

        func commit() {
            Current.settingsStore.connectionInfo?.setAddress(givenURL, urlType)

            if let section = form.sectionBy(tag: RowTag.ssids.rawValue) as? MultivaluedSection {
                Current.settingsStore.connectionInfo?.internalSSIDs = section.allRows
                    .compactMap { $0 as? TextRow }
                    .compactMap { $0.value }
            }

            onDismissCallback?(self)
        }

        updateNavigationItems(isChecking: true)

        firstly { () -> Promise<Void> in
            try check(url: givenURL)

            if let givenURL = givenURL {
                return Current.webhooks.sendTest(baseURL: givenURL)
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

    private enum RowTag: String {
        case url
        case ssids
    }

    private func updateNavigationItems(isChecking: Bool) {
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
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
                UIBarButtonItem(customView: activityIndicator)
            ]
        } else {
            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
            ]
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateNavigationItems(isChecking: false)

        form +++ Section()
        <<< URLRow(RowTag.url.rawValue) {
            $0.value = Current.settingsStore.connectionInfo?.address(for: urlType)
            $0.placeholder = { () -> String? in
                switch urlType {
                case .internal: return L10n.Settings.ConnectionSection.InternalBaseUrl.placeholder
                case .external: return L10n.Settings.ConnectionSection.ExternalBaseUrl.placeholder
                case .remoteUI: return nil
                }
            }()
        }

        if urlType.isAffectedByCloud, Current.settingsStore.connectionInfo?.useCloud == true {
            form +++ InfoLabelRow {
                $0.title = L10n.Settings.ConnectionSection.cloudOverridesExternal
            }
        }

        if urlType.isAffectedBySSID {
            form +++ locationPermissionSection()

            form +++ MultivaluedSection(
                multivaluedOptions: [.Insert, .Delete],
                header: L10n.Settings.ConnectionSection.InternalUrlSsids.header,
                footer: L10n.Settings.ConnectionSection.InternalUrlSsids.footer
            ) { section in
                section.tag = RowTag.ssids.rawValue
                section.addButtonProvider = { _ in
                    return ButtonRow {
                        $0.title = L10n.Settings.ConnectionSection.InternalUrlSsids.addNewSsid
                    }.cellUpdate { cell, _ in
                        cell.textLabel?.textAlignment = .natural
                    }
                }

                func row(for value: String?) -> TextRow {
                    TextRow {
                        $0.placeholder = L10n.Settings.ConnectionSection.InternalUrlSsids.placeholder
                        $0.value = value
                    }
                }

                section.multivaluedRowToInsertAt = { _ in
                    let current = ConnectionInfo.CurrentWiFiSSID

                    if section.allRows.contains(where: { ($0 as? TextRow)?.value == current }) {
                        return row(for: nil)
                    } else {
                        return row(for: current)
                    }
                }

                let existing = Current.settingsStore.connectionInfo?.internalSSIDs ?? []
                section.append(contentsOf: existing.map { row(for: $0) })
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
