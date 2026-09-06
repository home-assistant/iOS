import Foundation
import Shared

/// The player settings the protocol expects a client to keep across reboots — output delay, volume
/// and mute — plus the local choices that decide whether the player runs at all.
enum SendspinPreferences {
    private static let enabledKey = "sendspin.enabled"
    private static let nameKey = "sendspin.player_name"
    private static let outputDelayKey = "sendspin.output_delay_ms"
    private static let volumeKey = "sendspin.volume"
    private static let mutedKey = "sendspin.muted"
    private static let unpairedAccessKey = "sendspin.unpaired_access"
    private static let lastPlaybackServerKey = "sendspin.last_playback_server"
    private static let selectedServerKey = "sendspin.selected_server"

    private static var store: UserDefaults {
        UserDefaults(suiteName: AppConstants.AppGroupID) ?? .standard
    }

    static var isEnabled: Bool {
        get { store.bool(forKey: enabledKey) }
        set { store.set(newValue, forKey: enabledKey) }
    }

    /// The name servers show for this device. Defaults to the device's own name.
    static var playerName: String {
        get { store.string(forKey: nameKey) ?? Current.device.deviceName() }
        set { store.set(newValue, forKey: nameKey) }
    }

    /// Delay beyond the audio port, clamped to the protocol's 0-5000 ms range.
    static var outputDelayMilliseconds: Int {
        get { min(max(store.integer(forKey: outputDelayKey), 0), 5_000) }
        set { store.set(min(max(newValue, 0), 5_000), forKey: outputDelayKey) }
    }

    static var volume: Int {
        get { store.object(forKey: volumeKey) as? Int ?? 100 }
        set { store.set(min(max(newValue, 0), 100), forKey: volumeKey) }
    }

    static var isMuted: Bool {
        get { store.bool(forKey: mutedKey) }
        set { store.set(newValue, forKey: mutedKey) }
    }

    /// Whether a server with no pairing record may play audio here. Unpaired sessions are
    /// vulnerable to an on-path attacker impersonating either side, so this is the honest default
    /// for a phone on a home network but pairing is the upgrade.
    static var unpairedAccessEnabled: Bool {
        get { store.object(forKey: unpairedAccessKey) as? Bool ?? true }
        set { store.set(newValue, forKey: unpairedAccessKey) }
    }

    /// The `server_id` that most recently had playback, which the protocol asks clients to persist.
    static var lastPlaybackServerId: String? {
        get { store.string(forKey: lastPlaybackServerKey) }
        set { store.set(newValue, forKey: lastPlaybackServerKey) }
    }

    /// A server the user picked by hand, by Bonjour instance name. Nil means "whatever is found".
    static var selectedServerName: String? {
        get { store.string(forKey: selectedServerKey) }
        set { store.set(newValue, forKey: selectedServerKey) }
    }
}
