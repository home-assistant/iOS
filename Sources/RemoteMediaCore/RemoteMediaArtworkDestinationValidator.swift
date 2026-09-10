import Foundation

/// Decides whether an unauthenticated artwork request may leave the extension.
///
/// Artwork may be hosted on a local network, so this deliberately does not reject private or LAN
/// destinations. HTTPS, credentials, and a host are still checked before the initial request and
/// before every redirect.
public struct RemoteMediaArtworkDestinationValidator: Sendable {
    public init() {}

    /// Cheap checks used before advertising a URL to the extension.
    public static func hasAllowedSyntax(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        guard url.user == nil, url.password == nil else { return false }
        guard let host = normalizedHost(url.host), !host.isEmpty else { return false }
        return true
    }

    /// Full destination policy used immediately before opening a connection or following a redirect.
    public func allows(_ url: URL) async -> Bool {
        Self.hasAllowedSyntax(url)
    }

    private static func normalizedHost(_ host: String?) -> String? {
        guard var host = host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasPrefix("["), host.hasSuffix("]") {
            host.removeFirst()
            host.removeLast()
        }
        while host.hasSuffix(".") {
            host.removeLast()
        }
        return host
    }
}
