import Foundation

/// A server whose only route is an internal URL the watch can't verify (or that has no usable
/// URL at all). Drives the home screen's consent prompt and the settings "Needs attention"
/// explanation.
struct WatchInternalURLPromptContext: Identifiable {
    let serverId: String
    let serverName: String
    /// The internal URL the user may opt into; nil when the server has no internal URL either
    /// (nothing to opt into — the server needs fixing on the iPhone).
    let internalURL: URL?

    var id: String { serverId }
}
