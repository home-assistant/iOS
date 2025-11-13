import Eureka
import Shared
import SwiftUI

enum SettingsRootDataSource {
    static let buttonRows: [SettingsButtonRow] = {
        let fakeForm = Form()

        return SettingsRootDataSource.Row
            .allCases.map(\.row)
            .filter { row in
                if case let .function(_, function) = row.hidden {
                    // the function returns true to hide, so invert
                    return !function(fakeForm)
                } else {
                    return true
                }
            }
    }()

    enum Row: String, CaseIterable {
        case location
        case notifications
        case actions
        case complications
        case nfc

        var row: SettingsButtonRow {
            let row = { () -> SettingsButtonRow in
                switch self {
                case .location: return SettingsRootDataSource.location()
                case .notifications: return SettingsRootDataSource.notifications()
                case .actions: return SettingsRootDataSource.actions()
                case .complications: return SettingsRootDataSource.complications()
                case .nfc: return SettingsRootDataSource.nfc()
                }
            }()
            row.tag = rawValue
            return row
        }
    }

    private static func notifications() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.Settings.DetailsSection.NotificationSettingsRow.title
            $0.icon = .bellOutlineIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                NotificationSettingsViewController()
            }, onDismiss: nil)
        }
    }

    private static func location() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.Settings.DetailsSection.LocationSettingsRow.title
            $0.icon = .crosshairsGpsIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = .location
                return view
            }, onDismiss: nil)
        }
    }

    private static func actions() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.SettingsDetails.LegacyActions.title
            $0.icon = .gamepadVariantOutlineIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = .actions
                return view
            }, onDismiss: nil)
        }
    }

    private static func complications() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.Settings.DetailsSection.WatchRowComplications.title
            $0.icon = .chartDonutIcon
            $0.hidden = .isCatalyst
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                ComplicationListViewController()
            }, onDismiss: { _ in

            })
        }
    }

    private static func nfc() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.Nfc.List.title
            $0.icon = .nfcVariantIcon
            $0.hidden = .isCatalyst
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                NFCListViewController()
            }, onDismiss: nil)
        }
    }
}
