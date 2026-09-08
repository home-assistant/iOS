import Foundation

/// Translates the Companion server's connection state into the tiny context the extension needs.
///
/// The extension evaluates no network state of its own — it cannot afford the infrastructure that
/// would take — so the candidate webhook URLs are decided here, once, whenever what they depend on
/// changes.
public enum RemoteMediaTransportContextWriter {
    /// Endpoints in the order the extension should try.
    ///
    /// Cloudhook first when configured, then the external URL, then the internal one. This mirrors
    /// `ConnectionInfo.webhookURL()`'s preference for the cloudhook off the internal network, but
    /// keeps every reachable route as a fallback rather than committing to one: the extension may
    /// run on a different network from the one the app last saw, and iOS 27 has been denying the
    /// extension's local network path outright.
    public static func webhookURLs(for server: Server) -> [URL] {
        let connection = server.info.connection
        var urls: [URL] = []

        // The cloudhook is a webhook endpoint in its own right, and `evaluateWebhookURL()` already
        // prefers it off the internal network.
        if let cloudhookURL = connection.cloudhookURL {
            urls.append(cloudhookURL)
        }
        // `availableAuthenticationURLTypes` is remote UI > external > internal and already drops
        // remote UI when the user opted out of Home Assistant Cloud.
        for type in connection.availableAuthenticationURLTypes {
            guard let base = connection.address(for: type) else { continue }
            let url = base.appendingPathComponent(connection.webhookPath, isDirectory: false)
            guard !urls.contains(url) else { continue }
            urls.append(url)
        }
        return urls
    }

    public static func context(
        for selection: RemoteMediaSelection,
        server: Server
    ) -> RemoteMediaTransportContext {
        .init(
            selection: selection,
            webhookURLs: webhookURLs(for: server),
            secret: server.info.connection.webhookSecretBytes(version: server.info.version)
        )
    }
}
