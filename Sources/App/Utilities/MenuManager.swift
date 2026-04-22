import Foundation
import HAKit
import PromiseKit
import RealmSwift
import Shared
import UIKit

private extension UIMenu.Identifier {
    static var haActions: Self { .init(rawValue: "ha.actions") }
    static var haActionsConfigure: Self { .init(rawValue: "ha.actions.configure") }
    static var haHelp: Self { .init(rawValue: "ha.help") }
    static var haWebViewActions: Self { .init(rawValue: "ha.webViewActions") }
    static var haFile: Self { .init(rawValue: "ha.file") }
}

public struct MenuManagerTitleSubscription: Equatable {
    private var uuid = UUID()
    var server: Server
    var template: String
    var token: HACancellable

    init(server: Server, template: String, token: HACancellable) {
        self.server = server
        self.template = template
        self.token = token
    }

    func cancel() {
        token.cancel()
    }

    public static func == (lhs: MenuManagerTitleSubscription, rhs: MenuManagerTitleSubscription) -> Bool {
        lhs.uuid == rhs.uuid
    }
}

final class CompositeHACancellable: HACancellable {
    private var cancellables: [HACancellable]

    init(_ cancellables: [HACancellable] = []) {
        self.cancellables = cancellables
    }

    func append(_ cancellable: HACancellable) {
        cancellables.append(cancellable)
    }

    func cancel() {
        let activeCancellables = cancellables
        cancellables.removeAll()
        activeCancellables.forEach { $0.cancel() }
    }
}

private final class StatusItemTitleState {
    var hasRenderedTitle = false
    var hasReceivedLiveUpdate = false
}

enum StatusItemTitleRenderer {
    static func subscribe(
        api: HomeAssistantAPI,
        template: String,
        update: @escaping (String) -> Void
    ) -> HACancellable {
        let state = StatusItemTitleState()
        let cancellable = CompositeHACancellable()

        cancellable.append(api.connection.send(.init(
            type: .rest(.post, "template"),
            data: ["template": template]
        )) { result in
            switch result {
            case let .success(data):
                guard !state.hasReceivedLiveUpdate else {
                    return
                }

                state.hasRenderedTitle = true
                update(renderedTitle(from: data))
            case let .failure(error):
                Current.Log.error("Failed to render status item title via REST fallback: \(error)")
            }
        })

        cancellable.append(api.connection.subscribe(
            to: .renderTemplate(template),
            initiated: { result in
                guard case let .failure(error) = result else {
                    return
                }

                Current.Log.error("Failed to subscribe to status item title updates: \(error)")

                if !state.hasRenderedTitle {
                    update(L10n.errorLabel)
                }
            },
            handler: { _, response in
                state.hasRenderedTitle = true
                state.hasReceivedLiveUpdate = true
                update(String(describing: response.result))
            }
        ))

        return cancellable
    }

    private static func renderedTitle(from data: HAData) -> String {
        switch data {
        case let .primitive(value):
            return String(describing: value)
        case let .dictionary(value):
            return String(describing: value)
        case let .array(value):
            return String(describing: value)
        case .empty:
            return ""
        }
    }
}

class MenuManager {
    let builder: UIMenuBuilder
    let actionsWithImages: [(Action, UIImage)]

    // remember: this class is short-lived. it only exists for the duration of creating the menu.

    init(builder: UIMenuBuilder) {
        self.builder = builder
        self.actionsWithImages = Self.actionsWithImages()
        update()
    }

    static func url(from command: UICommand) -> URL? {
        guard let propertyList = command.propertyList as? [String: Any] else {
            return nil
        }

        guard let urlString = propertyList["url"] as? String else {
            return nil
        }

        return URL(string: urlString)
    }

    private static func propertyList(for url: URL) -> Any {
        ["url": url.absoluteString]
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Home Assistant"
    }

    public func subscribeStatusItemTitle(
        existing: MenuManagerTitleSubscription?,
        update: @escaping (String) -> Void
    ) -> MenuManagerTitleSubscription? {
        guard let (server, template) = Current.settingsStore.menuItemTemplate,
              Current.settingsStore.locationVisibility.isStatusItemVisible,
              !template.isEmpty else {
            update("")
            return nil
        }

        guard existing == nil || existing?.template != template || existing?.server != server else {
            return existing
        }

        // Cancel the old subscription before creating a new one
        existing?.cancel()

        // if we know it's going to change, reset it for now so it doesn't show the old value
        update("")

        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available to update status item title")
            return nil
        }

        return .init(
            server: server,
            template: template,
            token: StatusItemTitleRenderer.subscribe(api: api, template: template, update: update)
        )
    }

    public func update() {
        builder.remove(menu: .format)

        builder.replace(menu: .about, with: aboutMenu())

        if builder.menu(for: .preferences) == nil {
            // macOS prior to 11.3 doesn't have the preferences menu already and 11.3+ doesn't like it being inserted
            builder.insertSibling(preferencesMenu(), afterMenu: .about)
        } else {
            builder.replace(menu: .preferences, with: preferencesMenu())
        }

        builder.replaceChildren(ofMenu: .help) { _ in helpMenus() }

        if builder.menu(for: .haActions) == nil {
            builder.insertSibling(actionsMenu(), beforeMenu: .window)
        } else {
            builder.replace(menu: .haActions, with: actionsMenu())
        }

        if builder.menu(for: .haWebViewActions) == nil {
            builder.insertSibling(webViewActionsMenu(), beforeMenu: .fullscreen)
        } else {
            builder.replace(menu: .haWebViewActions, with: webViewActionsMenu())
        }

        if builder.menu(for: .haFile) == nil {
            builder.insertChild(fileMenu(), atStartOfMenu: .file)
        } else {
            builder.replace(menu: .haFile, with: fileMenu())
        }

        configureStatusItem()
    }

    private func aboutMenu() -> UIMenu {
        let title = L10n.Menu.Application.about(appName)

        let about = UICommand(
            title: title,
            image: nil,
            action: #selector(AppDelegate.openAbout),
            propertyList: nil
        )

        let checkForUpdates = UICommand(
            title: L10n.Updater.CheckForUpdatesMenu.title,
            image: nil,
            action: #selector(AppDelegate.checkForUpdate(_:)),
            propertyList: nil
        )

        var children: [UICommand] = [
            about,
        ]

        if Current.updater.isSupported {
            children.append(checkForUpdates)
        }

        return UIMenu(
            title: title,
            image: nil,
            identifier: .about,
            options: .displayInline,
            children: children
        )
    }

    private func aboutMenu() -> [AppMacBridgeStatusItemMenuItem] {
        [
            .init(name: L10n.About.title) { callbackInfo in
                Current.sceneManager.activateAnyScene(for: .about)
                callbackInfo.activate()
            },
            .init(name: L10n.Updater.CheckForUpdatesMenu.title) { callbackInfo in
                Current.sceneManager.activateAnyScene(for: .webView)
                callbackInfo.activate()

                UIApplication.shared.sendAction(
                    #selector(AppDelegate.checkForUpdate(_:)),
                    to: UIApplication.shared.delegate,
                    from: callbackInfo,
                    for: nil
                )
            },
        ]
    }

    private func preferencesMenu() -> UIMenu {
        let command = UIKeyCommand(
            title: L10n.Menu.Application.preferences,
            image: nil,
            action: #selector(AppDelegate.openPreferences),
            input: ",",
            modifierFlags: .command,
            propertyList: nil
        )

        return UIMenu(
            title: L10n.Menu.Application.preferences,
            image: nil,
            identifier: .preferences,
            options: .displayInline,
            children: [command]
        )
    }

    private func preferencesMenu() -> AppMacBridgeStatusItemMenuItem {
        .init(
            name: L10n.Menu.Application.preferences,
            keyEquivalentModifier: [.command],
            keyEquivalent: ","
        ) { callbackInfo in
            Current.sceneManager.activateAnyScene(for: .settings)
            callbackInfo.activate()
        }
    }

    private func helpMenus() -> [UIMenu] {
        let title = L10n.Menu.Help.help(appName)

        let helpCommand = UICommand(
            title: title,
            image: nil,
            action: #selector(AppDelegate.openHelp),
            propertyList: nil
        )

        return [
            UIMenu(
                title: title,
                image: nil,
                identifier: .haHelp,
                options: .displayInline,
                children: [helpCommand]
            ),
        ]
    }

    private static func actionsWithImages() -> [(Action, UIImage)] {
        // Action+Observation calls reload, so when they change this all gets run again
        Current.realm()
            .objects(Action.self)
            .sorted(byKeyPath: #keyPath(Action.Position))
            .map { action -> (Action, UIImage) in
                let iconRect = CGRect(x: 0, y: 0, width: 28, height: 28)

                let image = UIKit.UIGraphicsImageRenderer(size: iconRect.size).image { _ in
                    let imageRect = iconRect.insetBy(dx: 3, dy: 3)

                    UIColor(hex: action.BackgroundColor).set()
                    UIBezierPath(roundedRect: iconRect, cornerRadius: 6.0).fill()

                    MaterialDesignIcons(named: action.IconName)
                        .image(ofSize: imageRect.size, color: UIColor(hex: action.IconColor))
                        .draw(in: imageRect)
                }

                return (action, image)
            }
    }

    private func actionsMenu() -> UIMenu {
        let children = actionsWithImages.map { action, image in
            UICommand(
                title: action.Text,
                image: image,
                action: #selector(AppDelegate.openMenuUrl(_:)),
                propertyList: Self.propertyList(for: action.widgetLinkURL)
            )
        } + [
            UIMenu(title: "", image: nil, identifier: .haActionsConfigure, options: [.displayInline], children: [
                UICommand(
                    title: L10n.Menu.Actions.configure,
                    image: nil,
                    action: #selector(AppDelegate.openActionsPreferences),
                    propertyList: nil
                ),
            ]),
        ]

        return UIMenu(
            title: L10n.Menu.Actions.title,
            image: nil,
            identifier: .haActions,
            children: Array(children)
        )
    }

    private func actionsMenu() -> AppMacBridgeStatusItemMenuItem {
        var items = [AppMacBridgeStatusItemMenuItem]()
        items.append(contentsOf: actionsWithImages.compactMap { action, image in
            let url = action.widgetLinkURL

            return .init(
                name: action.Name,
                image: image
            ) { callbackInfo in
                callbackInfo.activate()

                let delegate: Guarantee<WebViewSceneDelegate> = Current.sceneManager.scene(
                    for: .init(activity: .webView)
                )
                delegate.done {
                    $0.urlHandler?.handle(url: url)
                }
            }
        })
        if !items.isEmpty {
            items.append(.separator())
        }
        items.append(.init(name: L10n.Menu.Actions.configure) { callbackInfo in
            callbackInfo.activate()

            UIApplication.shared.sendAction(
                #selector(AppDelegate.openActionsPreferences),
                to: UIApplication.shared.delegate,
                from: nil,
                for: nil
            )
        })

        return AppMacBridgeStatusItemMenuItem(name: L10n.Menu.Actions.title, subitems: items)
    }

    private func webViewActionsMenu() -> UIMenu {
        var commands: [UIMenuElement] = [
            UIKeyCommand(
                title: L10n.Menu.View.reloadPage,
                image: nil,
                action: #selector(refresh),
                input: "R",
                modifierFlags: [.command]
            ),
        ]

        // Add find menu item for iOS 16+
        if #available(iOS 16.0, *) {
            commands.append(UIKeyCommand(
                title: L10n.Menu.View.find,
                image: nil,
                action: #selector(showFindInteraction),
                input: "f",
                modifierFlags: [.command]
            ))
        }

        return UIMenu(
            title: "",
            image: nil,
            identifier: .haWebViewActions,
            options: .displayInline,
            children: commands
        )
    }

    private func fileMenu() -> UIMenu {
        UIMenu(
            title: "",
            image: nil,
            identifier: .haFile,
            options: .displayInline,
            children: [
                UIKeyCommand(
                    title: L10n.Menu.File.updateSensors,
                    image: nil,
                    action: #selector(updateSensors),
                    input: "R",
                    modifierFlags: [.command, .shift]
                ),
            ]
        )
    }

    private func toggleMenu() -> AppMacBridgeStatusItemMenuItem {
        .init(name: L10n.Menu.StatusItem.toggle(appName)) { callbackInfo in
            if callbackInfo.isActive {
                callbackInfo.deactivate()
            } else {
                Current.sceneManager.activateAnyScene(for: .webView)
                callbackInfo.activate()
            }
        }
    }

    private func quitMenu() -> AppMacBridgeStatusItemMenuItem {
        .init(
            name: L10n.Menu.StatusItem.quit,
            keyEquivalentModifier: [.command],
            keyEquivalent: "q"
        ) { callbackInfo in
            callbackInfo.terminate()
        }
    }

    private func configureStatusItem() {
        #if targetEnvironment(macCatalyst)
        if Current.settingsStore.locationVisibility.isDockVisible {
            Current.macBridge.activationPolicy = .regular
        } else {
            Current.macBridge.activationPolicy = .accessory
        }

        var menuItems = [AppMacBridgeStatusItemMenuItem]()
        menuItems.append(toggleMenu())
        menuItems.append(.separator())
        menuItems.append(actionsMenu())
        menuItems.append(.separator())
        menuItems.append(contentsOf: aboutMenu())
        menuItems.append(preferencesMenu())
        menuItems.append(quitMenu())

        Current.macBridge.configureStatusItem(using: AppMacBridgeStatusItemConfiguration(
            isVisible: Current.settingsStore.locationVisibility.isStatusItemVisible,
            image: Asset.statusItemIcon.image.cgImage!,
            imageSize: Asset.statusItemIcon.image.size,
            accessibilityLabel: appName,
            items: menuItems,
            primaryActionHandler: { callbackInfo in
                if callbackInfo.isActive {
                    callbackInfo.deactivate()
                } else {
                    Current.sceneManager.activateAnyScene(for: .webView)
                    callbackInfo.activate()
                }
            }
        ))
        #endif
    }

    // selectors that use responder chain
    @objc private func refresh() {}
    @objc private func updateSensors() {}
    @available(iOS 16.0, *)
    @objc private func showFindInteraction() {}
}
