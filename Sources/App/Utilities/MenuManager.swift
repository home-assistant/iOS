import Foundation
import UIKit
import RealmSwift
import Shared

@available(iOS 13, *)
private extension UIMenu.Identifier {
    static var haActions: Self { .init(rawValue: "ha.actions") }
    static var haActionsConfigure: Self { .init(rawValue: "ha.actions.configure") }
    static var haHelp: Self { .init(rawValue: "ha.help") }
    static var haWebViewActions: Self { .init(rawValue: "ha.webViewActions") }
    static var haFile: Self { .init(rawValue: "ha.file") }
}

@available(iOS 13, *)
class MenuManager {
    let builder: UIMenuBuilder

    private var realmTokens = [NotificationToken]()

    @available(iOS 13, *)
    init(builder: UIMenuBuilder) {
        self.builder = builder
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

    static private func propertyList(for url: URL) -> Any {
        return ["url": url.absoluteString]
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Home Assistant"
    }

    public func update() {
        builder.remove(menu: .format)

        builder.replace(menu: .about, with: aboutMenu())
        builder.insertSibling(preferencesMenu(), afterMenu: .about)
        builder.replaceChildren(ofMenu: .help) { _ in helpMenus() }
        builder.insertSibling(actionsMenu(), beforeMenu: .window)
        builder.insertSibling(webViewActionsMenu(), beforeMenu: .fullscreen)
        builder.insertChild(fileMenu(), atStartOfMenu: .file)

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
            about
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
            )
        ]
    }

    private func actionsMenu() -> UIMenu {
        // Action+Observation calls reload, so when they change this all gets run again
        let children = Current.realm()
            .objects(Action.self)
            .sorted(byKeyPath: #keyPath(Action.Position))
            .map { action -> UICommand in
                let iconRect = CGRect(x: 0, y: 0, width: 28, height: 28)

                let image = UIKit.UIGraphicsImageRenderer(size: iconRect.size).image { _ in
                    let imageRect = iconRect.insetBy(dx: 3, dy: 3)

                    UIColor(hex: action.BackgroundColor).set()
                    UIBezierPath(roundedRect: iconRect, cornerRadius: 6.0).fill()

                    MaterialDesignIcons(named: action.IconName)
                        .image(ofSize: imageRect.size, color: UIColor(hex: action.IconColor))
                        .draw(in: imageRect)
                }

                return UICommand(
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
                    )
                ])
            ]

        return UIMenu(
            title: L10n.Menu.Actions.title,
            image: nil,
            identifier: .haActions,
            options: [],
            children: Array(children)
        )
    }

    private func webViewActionsMenu() -> UIMenu {
        UIMenu(
            title: "",
            image: nil,
            identifier: .haWebViewActions,
            options: .displayInline,
            children: [
                UIKeyCommand(
                    title: L10n.Menu.View.reloadPage,
                    image: nil,
                    action: #selector(refresh),
                    input: "R",
                    modifierFlags: [.command]
                )
            ]
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
                )
            ]
        )
    }

    private func configureStatusItem() {
        #if targetEnvironment(macCatalyst)
        if Current.settingsStore.locationVisibility.isDockVisible {
            Current.macBridge.activationPolicy = .regular
        } else {
            Current.macBridge.activationPolicy = .accessory
        }

        Current.macBridge.configureStatusItem(using: AppMacBridgeStatusItemConfiguration(
            isVisible: Current.settingsStore.locationVisibility.isStatusItemVisible,
            image: Asset.statusItemIcon.image.cgImage!,
            imageSize: Asset.statusItemIcon.image.size,
            accessibilityLabel: appName,
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
}
