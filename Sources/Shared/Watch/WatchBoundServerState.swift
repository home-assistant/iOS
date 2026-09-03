import Foundation

/// The phone's servers as sent to the watch: `restorableState()` stamped with `companionDeviceName`.
public enum WatchBoundServerState {
    public static func encoded(servers: ServerManager = Current.servers) -> Data {
        stamp(servers.restorableState(), deviceName: \.mobileAppDeviceName)
    }

    /// Unreadable state is passed through untouched rather than dropped.
    static func stamp(_ state: Data, deviceName: (ServerInfo) -> String) -> Data {
        guard !state.isEmpty,
              let servers = try? JSONDecoder().decode([String: ServerInfo].self, from: state) else {
            return state
        }

        let stamped = servers.mapValues { info in
            var stamped = info
            stamped.setSetting(value: deviceName(info), for: .companionDeviceName)
            return stamped
        }

        do {
            // Sorted keys keep the bytes, and so the mirror's digest, stable across snapshots.
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return try encoder.encode(stamped)
        } catch {
            Current.Log.error("failed encoding watch-bound servers: \(error)")
            return state
        }
    }
}
