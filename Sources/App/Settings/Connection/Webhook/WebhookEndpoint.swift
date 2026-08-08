import Foundation

/// A webhook URL the app can use to talk to a server, together with where it came from.
struct WebhookEndpoint: Identifiable, Equatable {
    let source: WebhookEndpointSource
    /// `nil` when the source isn't configured for this server, e.g. no cloudhook without Home Assistant Cloud.
    let url: URL?

    var id: WebhookEndpointSource { source }
}
