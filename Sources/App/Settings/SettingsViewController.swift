import Communicator
import Eureka
import HAKit
import PromiseKit
import Shared

class SettingsViewController: HAFormViewController {
    struct ContentSection: OptionSet, ExpressibleByIntegerLiteral {
        let rawValue: Int
        init(rawValue: Int) { self.rawValue = rawValue }
        init(integerLiteral value: IntegerLiteralType) { self.init(rawValue: value) }

        static let servers: ContentSection = 0b1
        static let general: ContentSection = 0b10
        static let integrations: ContentSection = 0b11
        static let watch: ContentSection = 0b100
        static let carPlay: ContentSection = 0b101
        static let legacy: ContentSection = 0b110
        static let help: ContentSection = 0b111
        static let all = ContentSection(rawValue: ~0b0)
    }

    let contentSections: ContentSection
    init(contentSections: ContentSection = .all) {
        self.contentSections = contentSections
        super.init()
    }

    class func servers(controller: UIViewController) -> (Section, deallocate: () -> Void) {
        class Observer: ServerObserver {
            let updateRows: () -> Void
            init(updateRows: @escaping () -> Void) {
                self.updateRows = updateRows
            }

            func serversDidChange(_ serverManager: ServerManager) {
                guard UIApplication.shared.applicationState == .active else { return }
                UIView.performWithoutAnimation {
                    updateRows()
                }
            }
        }

        let section = MultivaluedSection(
            multivaluedOptions: [.Reorder, .Insert],
            header: L10n.Settings.ConnectionSection.serversHeader,
            footer: L10n.Settings.ConnectionSection.serversFooter
        )

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

            rows.append(LabelRow {
                $0.title = L10n.Settings.ConnectionSection.addServer
                $0.onCellSelection { _, row in
                    row.deselect(animated: true)
                    controller.present(
                        OnboardingNavigationView(onboardingStyle: .secondary).embeddedInHostingController(),
                        animated: true,
                        completion: nil
                    )
                }
            })

            section.removeAll()
            section.append(contentsOf: rows)
        }
        Current.servers.add(observer: observer)

        observer.updateRows()

        return (section, { Current.servers.remove(observer: observer) })
    }

    // swiftlint:disable:next cyclomatic_complexity
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
            let (section, deallocate) = Self.servers(controller: self)
            form +++ section
            after(life: self).done(deallocate)
        }

        if contentSections.contains(.general) {
            form +++ Section()
                <<< SettingsRootDataSource.Row.general.row
                <<< SettingsRootDataSource.Row.gestures.row
                <<< SettingsRootDataSource.Row.location.row
                <<< SettingsRootDataSource.Row.notifications.row
        }

        if contentSections.contains(.integrations) {
            form +++ Section()
                <<< SettingsRootDataSource.Row.sensors.row
                <<< SettingsRootDataSource.Row.nfc.row
                <<< SettingsRootDataSource.Row.widgets.row
        }

        // Display Apple Watch section only for devices that make sense
        // iPhones with paired watch
        let isWatchPaired = {
            if Current.isDebug {
                return true
            } else if case .paired = Communicator.shared.currentWatchState {
                return true
            }
            return false
        }()
        if isWatchPaired,
           contentSections.contains(.watch),
           UIDevice.current.userInterfaceIdiom == .phone {
            form +++ Section(header: "Apple Watch", footer: nil)
                <<< SettingsRootDataSource.Row.watch.row
                <<< SettingsRootDataSource.Row.complications.row
        }

        if UIDevice.current.userInterfaceIdiom == .phone {
            if contentSections.contains(.carPlay) {
                form +++ Section()
                    <<< SettingsRootDataSource.Row.carPlay.row
            }
        }

        if contentSections.contains(.legacy) {
            form +++ Section()
                <<< SettingsRootDataSource.Row.actions.row
        }
        if contentSections.contains(.help) {
            form +++ Section()
                <<< SettingsRootDataSource.Row.help.row
                <<< SettingsRootDataSource.Row.privacy.row
                <<< SettingsRootDataSource.Row.debugging.row
        }

        form +++ Section()
            <<< SettingsRootDataSource.Row.whatsNew.row

        // Set self as delegate to handle reordering
        tableView.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Current.appDatabaseUpdater.update()
    }

    @objc func openAbout(_ sender: UIButton) {
        let aboutView = AboutView().embeddedInHostingController()
        show(aboutView, sender: nil)
    }

    @objc func closeSettings(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    override func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        // Servers come already sorted by sortOrder, so we just need to update the order
        var servers = Current.servers.all
        let movedServer = servers.remove(at: sourceIndexPath.row)
        servers.insert(movedServer, at: destinationIndexPath.row)
        for (index, server) in servers.enumerated() {
            server.update { info in
                info.sortOrder = index
            }
        }
    }
}
