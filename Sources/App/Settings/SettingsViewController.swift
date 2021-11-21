import Eureka
import PromiseKit
import Shared

class SettingsViewController: HAFormViewController {
    struct ContentSection: OptionSet, ExpressibleByIntegerLiteral {
        let rawValue: Int
        init(rawValue: Int) { self.rawValue = rawValue }
        init(integerLiteral value: IntegerLiteralType) { self.init(rawValue: value) }

        static var servers: ContentSection = 0b1
        static var general: ContentSection = 0b10
        static var integrations: ContentSection = 0b100
        static var help: ContentSection = 0b1000
        static var all = ContentSection(rawValue: ~0b0)
    }

    let contentSections: ContentSection
    init(contentSections: ContentSection = .all) {
        self.contentSections = contentSections
        super.init()
    }

    class func servers() -> (Section, deallocate: () -> Void) {
        class Observer: ServerObserver {
            let updateRows: () -> Void
            init(updateRows: @escaping () -> Void) {
                self.updateRows = updateRows
            }

            func serversDidChange(_ serverManager: ServerManager) {
                UIView.performWithoutAnimation {
                    updateRows()
                }
            }
        }

        let section = Section()
        let observer = Observer {
            var rows = [BaseRow]()

            for server in Current.servers.all {
                rows.append(HomeAssistantAccountRow {
                    $0.value = .server(server)
                    $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                        ConnectionSettingsViewController(server: server)
                    }, onDismiss: nil)
                })
            }

            rows.append(HomeAssistantAccountRow {
                $0.value = .add
                $0.presentationMode = .show(controllerProvider: .callback(builder: { () -> UIViewController in
                    OnboardingNavigationViewController(onboardingStyle: .secondary)
                }), onDismiss: nil)
                $0.onCellSelection { _, row in
                    row.deselect(animated: true)
                }
            })

            section.removeAll()
            section.append(contentsOf: rows)
        }
        Current.servers.add(observer: observer)

        observer.updateRows()

        return (section, { Current.servers.remove(observer: observer) })
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
                ),
            ]
        }

        if !Current.sceneManager.supportsMultipleScenes || !Current.isCatalyst {
            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(
                    barButtonSystemItem: .done,
                    target: self,
                    action: #selector(closeSettings(_:))
                ),
            ]
        }

        if contentSections.contains(.servers) {
            let (section, deallocate) = Self.servers()
            form +++ section
            after(life: self).done(deallocate)
        }

        if contentSections.contains(.general) {
            form +++ Section()
                <<< SettingsRootDataSource.Row.general.row
                <<< SettingsRootDataSource.Row.location.row
                <<< SettingsRootDataSource.Row.notifications.row
        }

        if contentSections.contains(.integrations) {
            form +++ Section()
                <<< SettingsRootDataSource.Row.actions.row
                <<< SettingsRootDataSource.Row.sensors.row
                <<< SettingsRootDataSource.Row.complications.row
                <<< SettingsRootDataSource.Row.nfc.row
        }

        if contentSections.contains(.help) {
            form +++ Section()
                <<< SettingsRootDataSource.Row.help.row
                <<< SettingsRootDataSource.Row.privacy.row
                <<< SettingsRootDataSource.Row.debugging.row
        }
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
