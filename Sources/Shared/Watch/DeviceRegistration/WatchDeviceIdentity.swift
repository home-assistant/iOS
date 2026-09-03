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

    /// This watch, as it is right now. The watch app carries the same display name as the phone
    /// app, which is what the prefix comes from.
    public static func current(bundle: Bundle = .main) -> WatchDeviceIdentity {
        let displayName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ?? "Home Assistant"
        return WatchDeviceIdentity(
            appID: bundle.bundleIdentifier ?? AppConstants.BundleID,
            appName: appName(companionAppName: displayName),
            appVersion: HomeAssistantAPI.clientVersionDescription,
            deviceName: Current.device.deviceName(),
            deviceID: Current.settingsStore.integrationDeviceID,
            model: Current.device.systemModel(),
            osName: Current.device.systemName(),
            osVersion: Current.device.systemVersion()
        )
    }
}
