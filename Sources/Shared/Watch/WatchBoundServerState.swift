import Foundation

/// The phone's servers as the paired watch should receive them: `ServerManager.restorableState()`
/// with each server stamped with the device name the phone's own `mobile_app` registration carries
/// for it (`ServerSettingKey.companionDeviceName`).
///
/// The watch registers with Home Assistant as a device of its own, and names that registration
/// after the phone's so the two sort together — but it can't see the phone's name: watchOS names
/// every watch "Apple Watch", and the phone's override is only on the phone. Stamping the encoded
/// servers, rather than writing the setting into the phone's store, keeps it out of the phone's own
/// registrations and Keychain.
public enum WatchBoundServerState {
    /// `servers.restorableState()` with every server stamped. Both watch-bound paths — the on-demand
    /// `serversConfigSync` reply and the database mirror — go through here.
    public static func encoded(servers: ServerManager = Current.servers) -> Data {
        stamp(servers.restorableState(), deviceName: \.mobileAppDeviceName)
    }

    /// Adds `deviceName(info)` to every server in an encoded `[String: ServerInfo]`. State that
    /// can't be read back (an empty fake, an unexpected encoding) is passed through untouched rather
    /// than dropped: a server list the watch can't decode costs it nothing, a missing one costs it
    /// every server.
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
