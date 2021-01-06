import AppKit

class MacBridgeScreenImpl: NSObject, MacBridgeScreen {
    let screen: NSScreen

    init(screen: NSScreen) {
        self.screen = screen
    }

    var identifier: String {
        guard let displayID = screen.deviceDescription[.init("NSScreenNumber")] as? CGDirectDisplayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return "(error)"
        }

        return CFUUIDCreateString(nil, uuid) as String
    }

    var name: String {
        screen.localizedName
    }
}
