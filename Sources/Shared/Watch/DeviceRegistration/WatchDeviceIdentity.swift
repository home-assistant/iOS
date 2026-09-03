import Foundation

/// What the watch registers itself as with `mobile_app`.
public struct WatchDeviceIdentity: Equatable {
    public var appID: String
    public var appName: String
    public var appVersion: String
    public var deviceName: String
    public var deviceID: String
    public var model: String
    public var osName: String
    public var osVersion: String

    public init(
        appID: String,
        appName: String,
        appVersion: String,
        deviceName: String,
        deviceID: String,
        model: String,
        osName: String,
        osVersion: String
    ) {
        self.appID = appID
        self.appName = appName
        self.appVersion = appVersion
        self.deviceName = deviceName
        self.deviceID = deviceID
        self.model = model
        self.osName = osName
        self.osVersion = osVersion
    }

    /// The companion iPhone app's name with "Watch" appended, so the registration reads e.g.
    /// "Home Assistant Watch" and sorts next to the phone's in Home Assistant.
    public static func appName(companionAppName: String) -> String {
        "\(companionAppName) Watch"
    }

    /// The phone's device name in front of the watch's, e.g. "My iPhone Apple Watch".
    public static func deviceName(companionDeviceName: String?, watchName: String) -> String {
        guard let companion = companionDeviceName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !companion.isEmpty else {
            return watchName
        }
        return "\(companion) \(watchName)"
    }

    /// `base` with `attempt` appended, e.g. "My iPhone Apple Watch 2"; the first attempt is `base` itself.
    public static func deviceName(_ base: String, attempt: Int) -> String {
        attempt <= 1 ? base : "\(base) \(attempt)"
    }

    /// Whether `name` is `base` or `base` with a number appended.
    public static func isDeviceName(_ name: String?, variantOf base: String) -> Bool {
        guard let name else { return false }
        if name == base { return true }
        guard name.hasPrefix(base + " ") else { return false }
        return Int(name.dropFirst(base.count + 1)) != nil
    }

    /// The `device_name` the watch registers with `server`.
    public static func deviceName(for server: Server) -> String {
        deviceName(
            companionDeviceName: server.info.setting(for: .companionDeviceName),
            watchName: Current.device.deviceName()
        )
    }

    /// This watch, as it is right now, for a registration with `server`.
    public static func current(for server: Server, bundle: Bundle = .main) -> WatchDeviceIdentity {
        let displayName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ?? "Home Assistant"
        return WatchDeviceIdentity(
            appID: bundle.bundleIdentifier ?? AppConstants.BundleID,
            appName: appName(companionAppName: displayName),
            appVersion: HomeAssistantAPI.clientVersionDescription,
            deviceName: deviceName(for: server),
            deviceID: Current.settingsStore.integrationDeviceID,
            model: Current.device.systemModel(),
            osName: Current.device.systemName(),
            osVersion: Current.device.systemVersion()
        )
    }
}
