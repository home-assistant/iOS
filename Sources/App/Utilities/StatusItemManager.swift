#if targetEnvironment(macCatalyst) || os(macOS)
import Foundation
import Shared

/// Owns the Mac menu bar item: its icon, its templated title and the menu behind it.
final class StatusItemManager {
    private var titleSubscription: MenuManagerTitleSubscription? {
        didSet {
            if oldValue != titleSubscription {
                oldValue?.cancel()
            }
        }
    }

    private var shouldRefreshTitleSubscription = false

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Home Assistant"
    }

    func configure() {
        onMain { [self] in
            configureStatusItem()
            refreshTitleSubscription()
        }
    }

    func apiDidConnect() {
        onMain { [self] in
            shouldRefreshTitleSubscription = true
            refreshTitleSubscription()
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func refreshTitleSubscription() {
        titleSubscription = subscribeStatusItemTitle(
            existing: shouldRefreshTitleSubscription ? nil : titleSubscription,
            update: Current.macBridge.configureStatusItem(title:)
        )
        shouldRefreshTitleSubscription = false
    }

    private func subscribeStatusItemTitle(
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

        existing?.cancel()
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

    private func aboutMenu() -> [AppMacBridgeStatusItemMenuItem] {
        [
            .init(name: L10n.About.title) { callbackInfo in
                Current.sceneManager.activateAnyScene(for: .about)
                callbackInfo.activate()
            },
            .init(name: L10n.Updater.CheckForUpdatesMenu.title) { callbackInfo in
                Current.sceneManager.activateAnyScene(for: .webView)
                callbackInfo.activate()

                AppDelegate.shared?.checkForUpdate(callbackInfo)
            },
        ]
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
    }
}
#endif
