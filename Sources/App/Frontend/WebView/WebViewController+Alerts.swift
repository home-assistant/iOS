import Shared
import SwiftMessages
import SwiftUI
import UIKit

// MARK: - Alerts & Message Presentation

extension WebViewController {
    func show(alert: ServerAlert) {
        Current.Log.info("showing alert \(alert)")

        var config = swiftMessagesConfig()
        config.eventListeners.append({ event in
            switch event {
            case .didHide:
                Current.serverAlerter.markHandled(alert: alert)
            default:
                break
            }
        })

        let view = MessageView.viewFromNib(layout: .messageView)
        view.configureTheme(
            backgroundColor: UIColor(red: 1.000, green: 0.596, blue: 0.000, alpha: 1.0),
            foregroundColor: .white
        )
        view.configureContent(
            title: nil,
            body: alert.message,
            iconImage: nil,
            iconText: nil,
            buttonImage: nil,
            buttonTitle: L10n.openLabel,
            buttonTapHandler: { _ in
                URLOpener.shared.open(alert.url, options: [:], completionHandler: nil)
                SwiftMessages.hide()
            }
        )

        SwiftMessages.show(config: config, view: view)
    }

    func showSwiftMessage(error: Error, duration: SwiftMessages.Duration = .seconds(seconds: 15)) {
        Current.Log.error(error)
        var config = swiftMessagesConfig()
        config.duration = duration
        config.dimMode = .none

        let view = MessageView.viewFromNib(layout: .cardView)
        view.configureContent(
            title: L10n.Connection.Error.genericTitle,
            body: nil,
            iconImage: nil,
            iconText: nil,
            buttonImage: MaterialDesignIcons.helpCircleIcon.image(
                ofSize: .init(width: 35, height: 35),
                color: .haPrimary
            ),
            buttonTitle: nil,
            buttonTapHandler: { [weak self] _ in
                SwiftMessages.hide()
                guard let self else { return }
                presentOverlayController(
                    controller: UIHostingController(rootView: ConnectionErrorDetailsView(server: server, error: error)),
                    animated: true
                )
            }
        )
        view.titleLabel?.numberOfLines = 0
        view.bodyLabel?.numberOfLines = 0

        SwiftMessages.show(config: config, view: view)
    }

    func showReAuthPopup(serverId: String, code: Int) {
        guard serverId == server.identifier.rawValue else {
            return
        }
        var config = swiftMessagesConfig()
        config.duration = .forever
        let view = MessageView.viewFromNib(layout: .messageView)
        view.configureTheme(.warning)
        view.configureContent(
            title: L10n.Unauthenticated.Message.title,
            body: L10n.Unauthenticated.Message.body,
            iconImage: nil,
            iconText: nil,
            buttonImage: MaterialDesignIcons.cogIcon.image(
                ofSize: CGSize(width: 24, height: 24),
                color: .haPrimary
            ),
            buttonTitle: nil,
            buttonTapHandler: { [weak self] _ in
                self?.showSettingsViewController()
            }
        )
        view.titleLabel?.numberOfLines = 0
        view.bodyLabel?.numberOfLines = 0

        // Avoid retrying from Home Assistant UI since this is a dead end
        load(request: URLRequest(url: URL(string: "about:blank")!))
        showEmptyState()
        SwiftMessages.show(config: config, view: view)
    }

    func showActionAutomationEditorNotAvailable() {
        let alert = UIAlertController(
            title: L10n.Alerts.ActionAutomationEditor.Unavailable.title,
            message: L10n.Alerts.ActionAutomationEditor.Unavailable.body,
            preferredStyle: .alert
        )
        alert.addAction(.init(title: L10n.okLabel, style: .default))
        present(alert, animated: true)
    }

    func openDebug() {
        let controller = UIHostingController(rootView: AnyView(
            NavigationView {
                VStack {
                    HStack(spacing: DesignSystem.Spaces.half) {
                        Text(verbatim: L10n.Settings.Debugging.ShakeDisclaimerOptional.title)
                        Toggle(isOn: .init(get: {
                            Current.settingsStore.gestures[.shake] == .openDebug
                        }, set: { newValue in
                            Current.settingsStore.gestures[.shake] = newValue ? .openDebug : HAGestureAction.none
                        }), label: { EmptyView() })
                    }
                    .padding()
                    .background(Color.haPrimary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
                    .padding(DesignSystem.Spaces.one)
                    DebugView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                CloseButton { [weak self] in
                                    self?.dismissOverlayController(animated: true, completion: nil)
                                }
                            }
                        }
                }
            }
        ))
        presentOverlayController(controller: controller, animated: true)
    }

    func swiftMessagesConfig() -> SwiftMessages.Config {
        var config = SwiftMessages.Config()

        config.presentationContext = .viewController(self)
        config.duration = .forever
        config.presentationStyle = .bottom
        config.dimMode = .gray(interactive: true)
        config.dimModeAccessibilityLabel = L10n.cancelLabel

        return config
    }
}
