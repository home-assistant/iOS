import Foundation

/// Whether incoming calls ring through CallKit on this device.
///
/// The feature is opt-in: until the user switches it on, an `incoming_call` notification is shown as an
/// ordinary time-sensitive notification with Answer and Decline actions, exactly like any other notification.
///
/// It is read from the PushProvider extension as well as from the app, so it only looks at state both share:
/// the App Group defaults and the device.
public enum IncomingCallFeature {
    /// CallKit is not available to apps distributed in mainland China.
    static let unsupportedRegions: Set<String> = ["CN"]

    public static var isEnabled: Bool {
        isSupportedOnThisDevice && isSwitchedOn
    }

    /// Whether the switch is offered in Notification settings.
    public static var isOffered: Bool {
        isSupportedOnThisDevice
    }

    /// The device can run the feature at all.
    public static var isSupportedOnThisDevice: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return !Current.isCatalyst && !isInUnsupportedRegion(Locale.current)
        #else
        return false
        #endif
    }

    static func isInUnsupportedRegion(_ locale: Locale) -> Bool {
        guard let region = locale.regionCode?.uppercased() else { return false }
        return unsupportedRegions.contains(region)
    }

    private static var isSwitchedOn: Bool {
        guard Current.settingsStore.incomingCallsEnabled else { return false }
        // `Current.isTestFlight` reads the receipt of the running bundle, which an extension does not have, so
        // the extension trusts the stored switch. The app enforces the gate: it only offers the switch where
        // `isOffered`, and turns it back off on launch everywhere else (`enforceAvailability()`).
        return Current.isAppExtension || isOffered
    }

    /// Turns the switch off where it is not offered, for instance after moving from TestFlight to the App Store
    /// build, where the settings row that would turn it off is gone. Called by the app at launch.
    public static func enforceAvailability() {
        guard !Current.isAppExtension, !isOffered, Current.settingsStore.incomingCallsEnabled else { return }
        Current.settingsStore.incomingCallsEnabled = false
    }
}
