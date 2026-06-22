import AppKit

class MacBridgeStatusItem: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var lastConfiguration: MacBridgeStatusItemConfiguration?

    /// Holding any of these while clicking the status item opens the menu instead of toggling the app.
    private let menuModifiers: NSEvent.ModifierFlags = [.control, .option, .command]

    override init() {
        super.init()
        statusItem.button?.imagePosition = .imageLeading
    }

    func configure(title: String) {
        statusItem.button?.title = title
    }

    func configure(using configuration: MacBridgeStatusItemConfiguration) {
        lastConfiguration = configuration

        statusItem.isVisible = configuration.isVisible
        statusItem.button?.setAccessibilityLabel(configuration.accessibilityLabel)

        let image = NSImage(cgImage: configuration.image, size: configuration.imageSize)
        image.isTemplate = true
        statusItem.button?.image = image

        // A status item only routes a click to us once it has a menu assigned, and on modern macOS
        // the mouse button can't be read back in `menuWillOpen`. We therefore discriminate on the
        // modifier keys (which do read reliably there): a control/option/command + click opens the
        // menu, while a plain click runs the primary action (toggle the app).
        let menu = menu(for: configuration.items)
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard NSEvent.modifierFlags.isDisjoint(with: menuModifiers) else {
            // control / option / command + click: let the menu open.
            return
        }

        // Plain click: suppress the menu and run the primary action (toggle the app) instead.
        menu.cancelTrackingWithoutAnimation()

        guard let configuration = lastConfiguration else { return }
        let button = statusItem.button
        DispatchQueue.main.async {
            configuration.primaryActionHandler(MacBridgeStatusItemCallbackInfoImpl(sender: button))
        }
    }

    private func modifierKeys(for uglyMask: Int) -> NSEvent.ModifierFlags {
        var modifierMask: NSEvent.ModifierFlags = []
        let pairings: [(MacBridgeStatusModifierMask, NSEvent.ModifierFlags)] = [
            (.capsLock, .capsLock),
            (.shift, .shift),
            (.control, .control),
            (.option, .option),
            (.command, .command),
            (.numericPad, .numericPad),
            (.help, .help),
            (.function, .function),
        ]

        for (ugly, good) in pairings where uglyMask & ugly.rawValue != 0 {
            modifierMask.insert(good)
        }

        return modifierMask
    }

    private func menu(for items: [MacBridgeStatusItemMenuItem]) -> NSMenu {
        let menu = NSMenu()

        for item in items {
            guard !item.isSeparator else {
                menu.addItem(.separator())
                continue
            }

            let menuItem = NSMenuItem(
                title: item.name,
                action: #selector(actionTapped(_:)),
                keyEquivalent: item.keyEquivalent
            )
            menu.addItem(menuItem)

            menuItem.keyEquivalentModifierMask = modifierKeys(for: item.keyEquivalentModifierMask)
            menuItem.target = self
            menuItem.representedObject = item

            if let image = item.image, case let imageSize = item.imageSize, imageSize != .zero {
                menuItem.image = NSImage(cgImage: image, size: imageSize)
            }

            if !item.subitems.isEmpty {
                menuItem.submenu = self.menu(for: item.subitems)
            }
        }

        return menu
    }

    @objc private func actionTapped(_ sender: NSMenuItem) {
        guard let representedObject = sender.representedObject as? MacBridgeStatusItemMenuItem else { return }
        representedObject.primaryActionHandler(MacBridgeStatusItemCallbackInfoImpl(sender: sender))
    }
}

class MacBridgeStatusItemCallbackInfoImpl: MacBridgeStatusItemCallbackInfo {
    let sender: Any?

    init(sender: Any?) {
        self.sender = sender
    }

    var isActive: Bool {
        normalAppWindows.contains { window in
            window.isVisible && !window.isMiniaturized
        }
    }

    var hasWindows: Bool {
        !normalAppWindows.isEmpty
    }

    private var normalAppWindows: [NSWindow] {
        NSApp.windows.filter { window in
            window.level == .normal &&
                window.canBecomeKey
        }
    }

    func activate() {
        showAppWindows()
        DispatchQueue.main.async { [weak self] in
            self?.showAppWindows()
        }
    }

    func deactivate() {
        NSApp.hide(sender)
    }

    func terminate() {
        NSApp.terminate(sender)
    }

    private func showAppWindows() {
        NSApp.unhide(sender)

        for window in normalAppWindows {
            if window.isMiniaturized {
                window.deminiaturize(sender)
            }
            window.makeKeyAndOrderFront(sender)
            window.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}
