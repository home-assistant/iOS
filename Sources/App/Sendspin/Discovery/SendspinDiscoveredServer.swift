import Foundation

/// A Sendspin server found on the local network, resolved far enough to open a WebSocket to it.
struct SendspinDiscoveredServer: Identifiable, Equatable, Hashable {
    /// The Bonjour instance name, stable for as long as the server keeps advertising.
    let id: String
    /// The friendly name from the TXT record. Only a hint: `server/hello` is authoritative.
    let name: String
    let url: URL
}
