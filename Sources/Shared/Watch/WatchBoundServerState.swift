import Foundation

/// The phone's servers as sent to the watch: `restorableState()` stamped with `companionDeviceName`.
public enum WatchBoundServerState {
    public static func encoded(servers: ServerManager = Current.servers) -> Data {
        stamp(servers.restorableState(), deviceName: \.mobileAppDeviceName)
    }

    /// Unreadable state is passed through untouched rather than dropped.
    static func stamp(_ state: Data, deviceName: (ServerInfo) -> String) -> Data {
        guard !state.isEmpty,
              var servers = try? JSONDecoder().decode([String: ServerInfo].self, from: state) else {
            return state
        }

        for (identifier, info) in servers {
            var stamped = info
            stamped.setSetting(value: deviceName(info), for: .companionDeviceName)
            servers[identifier] = stamped
        }

        do {
            return try JSONEncoder().encode(servers)
        } catch {
            Current.Log.error("failed encoding watch-bound servers: \(error)")
            return state
        }
    }
}
