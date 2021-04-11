import Eureka
import Shared

class SettingsViewController: FormViewController {
    init() {
        if #available(iOS 13, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func servers() -> Section {
        let section = Section()

        for connection in [Current.apiConnection] {
            section <<< HomeAssistantAccountRow {
                $0.value = .init(
                    connection: connection,
                    locationName: prefs.string(forKey: "location_name")
                )
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    ConnectionSettingsViewController(connection: connection)
                }, onDismiss: nil)
            }
        }

        section <<< HomeAssistantAccountRow {
            $0.hidden = .isNotDebug
            $0.presentationMode = .show(controllerProvider: .callback(builder: { () -> UIViewController in
                fatalError()
            }), onDismiss: nil)
        }

        return section
    }

    private func general() -> Section {
        let section = Section()

        section <<< SettingsButtonRow {
            $0.title = L10n.SettingsDetails.General.title
            $0.icon = .paletteOutlineIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "general"
                return view
            }, onDismiss: nil)
        }

        section <<< SettingsButtonRow {
            $0.title = L10n.Settings.DetailsSection.LocationSettingsRow.title
            $0.icon = .crosshairsGpsIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "location"
                return view
            }, onDismiss: nil)
        }

        section <<< SettingsButtonRow {
            $0.title = L10n.Settings.DetailsSection.NotificationSettingsRow.title
            $0.icon = .bellOutlineIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                NotificationSettingsViewController()
            }, onDismiss: nil)
        }

        return section
    }

    private func integrations() -> Section {
        let section = Section()

        section <<< SettingsButtonRow {
            $0.title = L10n.SettingsDetails.Actions.title
            $0.icon = .gamepadVariantOutlineIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "actions"
                return view
            }, onDismiss: nil)
        }

        section <<< SettingsButtonRow {
            $0.title = L10n.SettingsSensors.title
            $0.icon = .formatListBulletedIcon
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                SensorListViewController()
            }, onDismiss: nil)
        }

        section <<< SettingsButtonRow {
            $0.title = L10n.Settings.DetailsSection.WatchRow.title
            $0.icon = .watchVariantIcon
            $0.hidden = .isCatalyst
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                ComplicationListViewController()
            }, onDismiss: { _ in

            })
        }

        section <<< SettingsButtonRow {
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

        return section
    }

    private func help() -> Section {
        let section = Section()

        section <<< SettingsButtonRow {
            $0.title = L10n.helpLabel
            $0.icon = .helpCircleOutlineIcon
            $0.accessoryIcon = .openInNewIcon
            $0.onCellSelection { [weak self] cell, row in
                openURLInBrowser(URL(string: "https://companion.home-assistant.io")!, self)
                row.deselect(animated: true)
            }
        }

        section <<< SettingsButtonRow {
            $0.title = L10n.SettingsDetails.Privacy.title
            $0.icon = .lockOutlineIcon
            $0.presentationMode = .show(controllerProvider: .callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "privacy"
                return view
            }, onDismiss: nil)
        }

        section <<< SettingsButtonRow {
            $0.title = L10n.Settings.Debugging.title
            $0.icon = .bugIcon
            $0.presentationMode = .show(controllerProvider: .callback {
                DebugSettingsViewController()
            }, onDismiss: nil)
        }

        return section
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.Settings.NavigationBar.title

        if !Current.isCatalyst {
            // About is in the Application menu on Catalyst, and closing the button is direct
            navigationItem.leftBarButtonItems = [
                UIBarButtonItem(
                    title: L10n.Settings.NavigationBar.AboutButton.title,
                    style: .plain,
                    target: self,
                    action: #selector(openAbout(_:))
                )
            ]
        }

        if !Current.sceneManager.supportsMultipleScenes || !Current.isCatalyst {
            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(
                    barButtonSystemItem: .done,
                    target: self,
                    action: #selector(closeSettings(_:))
                )
            ]
        }

        form.append(contentsOf: [
            servers(),
            general(),
            integrations(),
            help(),
        ])
    }

    @objc func openAbout(_ sender: UIButton) {
        let aboutView = AboutViewController()

        let navController = UINavigationController(rootViewController: aboutView)
        show(navController, sender: nil)
    }

    @objc func closeSettings(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
}
