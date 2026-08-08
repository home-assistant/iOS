import Foundation
import Shared
import UIKit

@MainActor
final class WebhookDetailViewModel: ObservableObject {
    @Published private(set) var endpoints: [WebhookEndpoint] = []
    @Published private(set) var activeSource: WebhookEndpointSource?
    @Published private(set) var activeURL: URL?
    @Published private(set) var results: [WebhookEndpointSource: WebhookReachabilityResult] = [:]
    @Published private(set) var checksInFlight: Set<WebhookEndpointSource> = []

    private let server: Server

    init(server: Server) {
        self.server = server
        evaluate(connection: server.info.connection)
    }

    var activeSourceTitle: String {
        activeSource?.title ?? L10n.Settings.ConnectionSection.Webhook.Active.unavailable
    }

    func isChecking(_ endpoint: WebhookEndpoint) -> Bool {
        checksInFlight.contains(endpoint.source)
    }

    func result(for endpoint: WebhookEndpoint) -> WebhookReachabilityResult? {
        results[endpoint.source]
    }

    /// Re-evaluates which URL the webhook currently resolves to, refreshing network information
    /// (e.g. the current SSID) first so the answer matches what a real request would do right now.
    func refresh() async {
        var connection = server.info.connection
        _ = await connection.webhookURL()
        evaluate(connection: connection)
    }

    func copyURL(of endpoint: WebhookEndpoint) {
        guard let url = endpoint.url else { return }
        UIPasteboard.general.string = url.absoluteString
    }

    func copyActiveURL() {
        guard let activeURL else { return }
        UIPasteboard.general.string = activeURL.absoluteString
    }

    func checkReachability(for endpoint: WebhookEndpoint) async {
        guard let url = endpoint.url, !checksInFlight.contains(endpoint.source) else { return }

        checksInFlight.insert(endpoint.source)
        defer { checksInFlight.remove(endpoint.source) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil

        let session = URLSession(
            configuration: configuration,
            delegate: WebhookReachabilitySessionDelegate(connection: server.info.connection),
            delegateQueue: nil
        )
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await session.data(for: request)
            results[endpoint.source] = .reachable(statusCode: (response as? HTTPURLResponse)?.statusCode)
        } catch {
            results[endpoint.source] = .unreachable(message: error.localizedDescription)
        }
    }

    /// `connectionInfo` is a copy of the server's connection info, so evaluating URLs on it here
    /// has no effect on the connection the rest of the app uses.
    private func evaluate(connection connectionInfo: ConnectionInfo) {
        let cloudhookURL = connectionInfo.cloudhookURL
        let webhookPath = connectionInfo.webhookPath

        func webhookURL(for urlType: ConnectionInfo.URLType) -> URL? {
            connectionInfo.address(for: urlType)?
                .sanitized()
                .appendingPathComponent(webhookPath, isDirectory: false)
        }

        // The cloudhook is always listed, even when absent, so it is clear whether the webhook comes
        // from Home Assistant Cloud or from one of this server's own URLs.
        var resolvedEndpoints = [WebhookEndpoint(source: .cloudhook, url: cloudhookURL)]
        if let url = webhookURL(for: .internal) {
            resolvedEndpoints.append(WebhookEndpoint(source: .internalURL, url: url))
        }
        if let url = webhookURL(for: .remoteUI) {
            resolvedEndpoints.append(WebhookEndpoint(source: .remoteUI, url: url))
        }
        if let url = webhookURL(for: .external) {
            resolvedEndpoints.append(WebhookEndpoint(source: .externalURL, url: url))
        }
        endpoints = resolvedEndpoints

        var connection = connectionInfo
        let resolvedURL = connection.evaluateWebhookURL()
        activeURL = resolvedURL

        if resolvedURL == nil {
            activeSource = nil
        } else if resolvedURL == cloudhookURL {
            activeSource = .cloudhook
        } else {
            switch connection.activeURLType {
            case .internal: activeSource = .internalURL
            case .remoteUI: activeSource = .remoteUI
            case .external: activeSource = .externalURL
            case .none: activeSource = nil
            }
        }
    }
}
