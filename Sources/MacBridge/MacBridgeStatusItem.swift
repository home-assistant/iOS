import AppKit

class MacBridgeStatusItem {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var lastConfiguration: MacBridgeStatusItemConfiguration?

    init() {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemTapped(_:))
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
        lastConfiguration?.primaryActionHandler(MacBridgeStatusItemCallbackInfoImpl())
    }
}

class MacBridgeStatusItemCallbackInfoImpl: MacBridgeStatusItemCallbackInfo {
    var isActive: Bool {
        NSApp.isActive
    }

    func activate() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func deactivate() {
        NSApp.hide(nil)
    }
}
