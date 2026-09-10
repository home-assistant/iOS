import Foundation

public extension RemoteMediaTransportContextWriter {
    /// Stores the context for the followed player, or clears it when nothing is followed.
    ///
    /// Secrets and routes are rebuilt from the live server configuration. Only the small context
    /// needed by the extension crosses the App Group boundary.
    static func update(for selection: RemoteMediaSelection?) {
        guard let selection,
              let server = Current.servers.server(forServerIdentifier: selection.serverId) else {
            RemoteMediaTransportStore.clear()
            return
        }
        do {
            try RemoteMediaTransportStore.save(context(for: selection, server: server))
        } catch {
            Current.Log.error("Remote media transport context could not be stored: \(error)")
        }
    }
}
