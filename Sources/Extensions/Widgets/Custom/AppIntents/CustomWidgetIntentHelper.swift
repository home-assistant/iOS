import Foundation
import HAKit
import Shared

@available(iOS 16.4, *)
enum CustomWidgetIntentHelper {
    /// Returns the active `HAConnection` for `serverId`, or nil if it can't be
    /// resolved. When `activeURL` is nil, dispatches a local notification so a
    /// tap doesn't silently do nothing.
    static func resolveConnection(
        serverId: String,
        intentName: String
    ) -> HAConnection? {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            Current.Log.error("\(intentName): server not found, serverId: \(serverId)")
            return nil
        }
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log
                .error("\(intentName): no API for server (activeURL is nil), serverId: \(serverId)")
            Current.notificationDispatcher.send(.init(
                id: .serverUnreachable,
                title: L10n.Widgets.Custom.ServerUnreachable.title,
                body: L10n.Widgets.Custom.ServerUnreachable.body
            ))
            return nil
        }
        return connection
    }
}
