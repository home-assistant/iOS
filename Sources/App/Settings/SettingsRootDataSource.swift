import Eureka
import Shared

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
        case general
        case servers
        case location
        case notifications
        case actions
        case sensors
        case complications
        case nfc
        case help
        case privacy
        case debugging

        var row: SettingsButtonRow {
            let row = { () -> SettingsButtonRow in
                switch self {
                case .servers: return SettingsRootDataSource.servers()
                case .general: return SettingsRootDataSource.general()
                case .location: return SettingsRootDataSource.location()
                case .notifications: return SettingsRootDataSource.notifications()
                case .actions: return SettingsRootDataSource.actions()
                case .sensors: return SettingsRootDataSource.sensors()
                case .complications: return SettingsRootDataSource.complications()
                case .nfc: return SettingsRootDataSource.nfc()
                case .help: return SettingsRootDataSource.help()
                case .privacy: return SettingsRootDataSource.privacy()
                case .debugging: return SettingsRootDataSource.debugging()
                }
            }()
            row.tag = rawValue
            return row
        }
    }

    private static func servers() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.Settings.ConnectionSection.servers
            $0.icon = .serverIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                SettingsViewController(contentSections: .servers)
            }, onDismiss: nil)
        }
    }

    private static func general() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.SettingsDetails.General.title
            $0.icon = .paletteOutlineIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "general"
                return view
            }, onDismiss: nil)
        }
    }

    private static func location() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.Settings.DetailsSection.LocationSettingsRow.title
            $0.icon = .crosshairsGpsIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "location"
                return view
            }, onDismiss: nil)
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

    private static func actions() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.SettingsDetails.Actions.title
            $0.icon = .gamepadVariantOutlineIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "actions"
                return view
            }, onDismiss: nil)
        }
    }

    private static func sensors() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.SettingsSensors.title
            $0.icon = .formatListBulletedIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                SensorListViewController()
            }, onDismiss: nil)
        }
    }

    private static func complications() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.Settings.DetailsSection.WatchRow.title
            $0.icon = .watchVariantIcon
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

            if #available(iOS 13, *) {
                $0.hidden = .isCatalyst
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    NFCListViewController()
                }, onDismiss: nil)
            } else {
                $0.hidden = true
            }
        }
    }

    private static func help() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.helpLabel
            $0.icon = .helpCircleOutlineIcon
            $0.accessoryIcon = .openInNewIcon
            $0.hidden = .isCatalyst
            $0.onCellSelection { cell, row in
                openURLInBrowser(URL(string: "https://companion.home-assistant.io")!, cell.formViewController())
                row.deselect(animated: true)
            }
        }
    }

    private static func privacy() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.SettingsDetails.Privacy.title
            $0.icon = .lockOutlineIcon
            $0.presentationMode = .show(controllerProvider: .callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "privacy"
                return view
            }, onDismiss: nil)
        }
    }

    private static func debugging() -> SettingsButtonRow {
        SettingsButtonRow {
            $0.title = L10n.Settings.Debugging.title
            $0.icon = .bugIcon
            $0.presentationMode = .show(controllerProvider: .callback {
                DebugSettingsViewController()
            }, onDismiss: nil)
        }
    }
}
