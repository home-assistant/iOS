#if os(iOS)
import Foundation
import HAKit
import PromiseKit
import Shared
import UIKit

private extension UIMenu.Identifier {
    static var haWebViewActions: Self { .init(rawValue: "ha.webViewActions") }
    static var haFile: Self { .init(rawValue: "ha.file") }
}

class MenuManager {
    let builder: UIMenuBuilder

    // remember: this class is short-lived. it only exists for the duration of creating the menu.

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

    private func aboutMenu() -> [AppMacBridgeStatusItemMenuItem] {
        [
            .init(name: L10n.About.title) { callbackInfo in
                Current.sceneManager.activateAnyScene(for: .about)
                callbackInfo.activate()
            },
            .init(name: L10n.Updater.CheckForUpdatesMenu.title) { callbackInfo in
                Current.sceneManager.activateAnyScene(for: .webView)
                callbackInfo.activate()

                // Under the SwiftUI `App` lifecycle `UIApplication.shared.delegate` is SwiftUI's internal
                // delegate, which doesn't respond to `checkForUpdate(_:)`; target our recorded instance.
                UIApplication.shared.sendAction(
                    #selector(AppDelegate.checkForUpdate(_:)),
                    to: AppDelegate.shared,
                    from: callbackInfo,
                    for: nil
                )
            },
        ]
    }

    private func preferencesMenu() -> AppMacBridgeStatusItemMenuItem {
        .init(
            name: L10n.Menu.Application.settings,
            keyEquivalentModifier: [.command],
            keyEquivalent: ","
        ) { callbackInfo in
            Current.sceneManager.activateAnyScene(for: .settings)
            callbackInfo.activate()
        }
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

        commands.append(UIKeyCommand(
            title: L10n.Menu.View.find,
            image: nil,
            action: #selector(showFindInteraction),
            input: "f",
            modifierFlags: [.command]
        ))

        #if targetEnvironment(macCatalyst)
        commands.append(UICommand(
            title: L10n.Menu.View.customizeToolbar,
            image: nil,
            action: #selector(customizeToolbar)
        ))
        #endif

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
            if StatusItemPrimaryAction.openInBrowserIfNeeded() { return }
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
                if StatusItemPrimaryAction.openInBrowserIfNeeded() { return }
                if callbackInfo.isActive {
                    callbackInfo.deactivate()
                } else if callbackInfo.hasWindows {
                    callbackInfo.activate()
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
    @objc private func showFindInteraction() {}
    @objc private func customizeToolbar() {}
}
#endif
