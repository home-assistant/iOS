import AppKit

class MacBridgeStatusItem: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var lastConfiguration: MacBridgeStatusItemConfiguration?

    override init() {
        super.init()
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemTapped(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .leftMouseDown, .rightMouseDown])
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
    }

    @objc private func statusItemTapped(_ sender: NSStatusBarButton) {
        guard let configuration = lastConfiguration, let event = NSApp.currentEvent else { return }

        if event.isRightClickEquivalentEvent {
            let mainMenu = menu(for: configuration.items)
            mainMenu.delegate = self
            statusItem.menu = mainMenu
            sender.performClick(sender)
        } else if event.type == .leftMouseUp {
            // leftMouseDown also fires, but we only want to do that for ctrl-clicks
            configuration.primaryActionHandler(MacBridgeStatusItemCallbackInfoImpl(sender: sender))
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
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
        // Only treat the app as "active" (and therefore something to hide on the next click) when it
        // actually has a visible standard window. In menu-bar (`.accessory`) mode `NSApp.isActive` can be
        // true with no visible window — which previously made the status-item click hide the app instead of
        // showing it, so the icon appeared to do nothing.
        NSApp.isActive && NSApp.windows.contains { $0.isVisible && !$0.isMiniaturized && $0.level == .normal }
    }

    func activate() {
        NSApp.activate(ignoringOtherApps: true)
        // `NSApp.activate` un-hides the app but doesn't reliably bring a closed/ordered-out window back in
        // accessory mode, so surface an existing standard window here. A brand-new window (when none exists)
        // is created by the scene-activation request in `SceneManager.activateAnyScene`.
        NSApp.windows
            .first { $0.level == .normal && !$0.isMiniaturized }?
            .makeKeyAndOrderFront(nil)
    }

    func deactivate() {
        NSApp.hide(sender)
    }

    func terminate() {
        NSApp.terminate(sender)
    }
}
