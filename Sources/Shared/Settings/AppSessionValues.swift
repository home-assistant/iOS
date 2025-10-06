import Foundation

public protocol AppSessionValuesProtocol {
    var inviteURL: URL? { get set }
}

/// Values stored for the given app session until terminated by the OS.
final class AppSessionValues: AppSessionValuesProtocol {
    static var shared = AppSessionValues()
    /// The URL from the SH-PRO invitation link
    public var inviteURL: URL?
}
