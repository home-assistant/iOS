import Foundation

/// The App Group the RemoteMedia extension and the host app share.
///
/// Derived the same way `AppConstants.AppGroupID` derives it, but without reaching into `Shared`:
/// the extension has a 6144 KB ledger and cannot afford the Companion dependency graph, and this
/// file is compiled into both targets so the two can never disagree about the identifier.
public enum RemoteMediaAppGroup {
    public static var identifier: String? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let hostID = bundleID.hasSuffix(extensionSuffix)
            ? String(bundleID.dropLast(extensionSuffix.count))
            : bundleID
        return "group." + hostID.lowercased()
    }

    public static var containerURL: URL? {
        identifier.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
    }

    private static let extensionSuffix = ".RemoteMedia"
}
