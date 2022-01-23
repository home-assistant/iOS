import Eureka
import FirebaseInstallations
import FirebaseMessaging
import PromiseKit
import RealmSwift
import Shared
import UIKit

class NotificationSettingsViewController: HAFormViewController {
    public var doneButton: Bool = false

    private var observerTokens: [Any] = []

    deinit {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if doneButton {
            navigationItem.rightBarButtonItem = nil
            doneButton = false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if doneButton {
            let doneButton = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(closeSettingsDetailView(_:))
            )
            navigationItem.setRightBarButton(doneButton, animated: true)
        }

        title = L10n.SettingsDetails.Notifications.title

        form
            +++ Section()
            <<< InfoLabelRow {
                $0.title = L10n.SettingsDetails.Notifications.info
                $0.displayType = .primary
            }

            <<< notificationPermissionRow()

            <<< LearnMoreButtonRow {
                $0.value = URL(string: "https://companion.home-assistant.io/app/ios/notifications")!
            }

            +++ Section(
                footer: L10n.SettingsDetails.Notifications.Sounds.footer
            )

            <<< ButtonRow {
                $0.title = L10n.SettingsDetails.Notifications.Sounds.title
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    NotificationSoundsViewController()
                }, onDismiss: nil)
            }

            +++ Section(footer: L10n.SettingsDetails.Notifications.BadgeSection.AutomaticSetting.description)

            <<< ButtonRow {
                $0.title = L10n.SettingsDetails.Notifications.BadgeSection.Button.title
                $0.cellStyle = .value1

                var lastValue: Int?
                let update = { [weak row = $0] in
                    guard let row = row else { return }

                    let value = UIApplication.shared.applicationIconBadgeNumber
                    guard value != lastValue else { return }

                    row.value = NumberFormatter.localizedString(
                        from: NSNumber(value: value),
                        number: .decimal
                    )
                    row.updateCell()

                    lastValue = value
                }

                // timer because kvo only works on manually changing it, and this is easiest/cheap
                let timer = Timer.scheduledTimer(
                    withTimeInterval: 1.0,
                    repeats: true,
                    block: { _ in update() }
                )
                // kvo so internally setting it updates instantly
                let token = UIApplication.shared.observe(
                    \.applicationIconBadgeNumber,
                    changeHandler: { _, _ in update() }
                )

                update()

                after(life: self).done {
                    token.invalidate()
                    timer.invalidate()
                }

                $0.cellUpdate { cell, row in
                    cell.textLabel?.textAlignment = .natural
                    cell.detailTextLabel?.text = row.value
                }
                $0.onCellSelection { _, _ in
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
            }

            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Notifications.BadgeSection.AutomaticSetting.title
                $0.value = Current.settingsStore.clearBadgeAutomatically
                $0.onChange { row in
                    Current.settingsStore.clearBadgeAutomatically = row.value ?? true
                }
            }

            +++ Section()

            <<< ButtonRow {
                $0.title = L10n.SettingsDetails.Notifications.Categories.header
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    NotificationCategoryListViewController()
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
                })
            }

            <<< InfoLabelRow {
                $0.title = L10n.SettingsDetails.Notifications.Categories.deprecatedNote
            }

            +++ Section(
                header: L10n.debugSectionLabel,
                footer: nil
            )

            <<< ButtonRowOf<Int> { row in
                let value = NotificationRateLimitListViewController.newPromise()

                row.cellStyle = .value1

                func update(for response: RateLimitResponse) {
                    row.value = response.rateLimits.remaining
                    row.updateCell()
                }

                value.done { response in
                    update(for: response)
                }.cauterize()

                row.title = L10n.SettingsDetails.Notifications.RateLimits.header
                row.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    let controller = NotificationRateLimitListViewController(initialPromise: value)
                    controller.rateLimitDidChange = { rateLimit in
                        update(for: rateLimit)
                    }
                    return controller
                }, onDismiss: nil)

                row.displayValueFor = { value in
                    value.map {
                        NumberFormatter.localizedString(
                            from: NSNumber(value: $0),
                            number: .decimal
                        )
                    }
                }
            }

            <<< ButtonRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.header
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    NotificationDebugNotificationsViewController()
                }, onDismiss: nil)
            }

            <<< LabelRow("pushID") {
                $0.title = L10n.SettingsDetails.Notifications.PushIdSection.header

                if let pushID = Current.settingsStore.pushID {
                    $0.value = pushID
                } else {
                    $0.value = L10n.SettingsDetails.Notifications.PushIdSection.notRegistered
                }

                $0.cellSetup { cell, _ in
                    cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
                }

                $0.cellUpdate { cell, _ in
                    cell.selectionStyle = .default
                }

                $0.onCellSelection { [weak self] cell, row in
                    guard let id = Current.settingsStore.pushID else { return }

                    let vc = UIActivityViewController(activityItems: [id], applicationActivities: nil)
                    with(vc.popoverPresentationController) {
                        $0?.sourceView = cell
                        $0?.sourceRect = cell.bounds
                    }
                    self?.present(vc, animated: true, completion: nil)
                    row.deselect(animated: true)
                }
            }

            <<< ButtonRow {
                $0.tag = "resetPushID"
                $0.title = L10n.Settings.ResetSection.ResetRow.title
            }.cellUpdate { cell, _ in
                cell.textLabel?.textColor = .red
            }.onCellSelection { [weak self] cell, _ in
                Current.Log.verbose("Resetting push token!")

                firstly {
                    Current.notificationManager.resetPushID()
                }.done { token in
                    guard let idRow = self?.form.rowBy(tag: "pushID") as? LabelRow else { return }
                    idRow.value = token
                    idRow.updateCell()
                }.then { _ in
                    when(fulfilled: Current.apis.map { $0.updateRegistration() })
                }.catch { error in
                    Current.Log.error("Error resetting push token: \(error)")
                    let alert = UIAlertController(
                        title: L10n.errorLabel,
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )

                    alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))

                    self?.present(alert, animated: true, completion: nil)
                    alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
                }
            }
    }

    @objc func closeSettingsDetailView(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    private func notificationPermissionRow() -> BaseRow {
        var lastPermissionSeen: UNAuthorizationStatus?

        func update(_ row: LabelRow) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    lastPermissionSeen = settings.authorizationStatus

                    row.value = {
                        switch settings.authorizationStatus {
                        case .ephemeral:
                            return L10n.SettingsDetails.Notifications.Permission.enabled
                        case .authorized, .provisional:
                            return L10n.SettingsDetails.Notifications.Permission.enabled
                        case .denied:
                            return L10n.SettingsDetails.Notifications.Permission.disabled
                        case .notDetermined:
                            return L10n.SettingsDetails.Notifications.Permission.needsRequest
                        @unknown default:
                            return L10n.SettingsDetails.Notifications.Permission.disabled
                        }
                    }()
                    row.updateCell()
                }
            }
        }

        return LabelRow { row in
            row.title = L10n.SettingsDetails.Notifications.Permission.title
            update(row)

            observerTokens.append(NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                // in case the user jumps to settings and changes while we're open, update the value
                update(row)
            })

            row.cellUpdate { cell, _ in
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }

            row.onCellSelection { _, row in
                UNUserNotificationCenter.current().requestAuthorization(options: .defaultOptions) { _, _ in
                    DispatchQueue.main.async {
                        update(row)
                        row.deselect(animated: true)

                        if lastPermissionSeen != .notDetermined {
                            // if we weren't prompting for permission with this request, open settings
                            // we can't avoid the request code-path since getting settings is async
                            UIApplication.shared.openSettings(destination: .notification)
                        }
                    }
                }
            }
        }
    }
}
