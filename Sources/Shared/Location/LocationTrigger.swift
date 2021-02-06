import CoreLocation
import Foundation

public enum LocationUpdateTrigger: String, CaseIterable {
    public struct NotificationOptions {
        public let shouldNotify: Bool
        public let identifier: String?
        public let title: String
        public let body: String
    }

    case RegionEnter = "Region Entered"
    case RegionExit = "Region Exited"
    case GPSRegionEnter = "Geographic Region Entered"
    case GPSRegionExit = "Geographic Region Exited"
    case BeaconRegionEnter = "iBeacon Region Entered"
    case BeaconRegionExit = "iBeacon Region Exited"
    case Manual = "Manual"
    case SignificantLocationUpdate = "Significant Location Change"
    case BackgroundFetch = "Background Fetch"
    case PushNotification = "Push Notification"
    case URLScheme = "URL Scheme"
    case XCallbackURL = "X-Callback-URL"
    case Siri = "Siri"
    case Visit = "Visit"
    case AppShortcut = "App Shortcut"
    case Launch = "Launch"
    case Periodic = "Periodic"
    case Signaled = "Signaled"
    case Unknown = "Unknown"

    public func oneShotTimeout(maximum: TimeInterval?) -> TimeInterval {
        if let maximum = maximum {
            // the system appears to have given us a reasonable baseline, leave some time for network call
            return max(maximum - 5.0, 1.0)
        }

        switch self {
        case .RegionEnter, .RegionExit, .GPSRegionEnter, .GPSRegionExit, .BeaconRegionEnter, .BeaconRegionExit, .Visit:
            // location events, we've probably got a bit more freedom
            return 20.0
        case .SignificantLocationUpdate, .BackgroundFetch, .PushNotification:
            // background events we know are usually time sensitive
            return 10.0
        case .Manual, .URLScheme, .XCallbackURL, .AppShortcut, .Siri, .Launch, .Periodic, .Signaled:
            // user is actively doing this, so wait a little longer
            return 30.0
        case .Unknown:
            return 10.0
        }
    }

    public var notificationPreferenceKey: String? {
        switch self {
        case .BeaconRegionEnter: return "beaconEnterNotifications"
        case .BeaconRegionExit: return "beaconExitNotifications"
        case .GPSRegionEnter: return "enterNotifications"
        case .GPSRegionExit: return "exitNotifications"
        case .SignificantLocationUpdate: return "significantLocationChangeNotifications"
        case .BackgroundFetch: return "backgroundFetchLocationChangeNotifications"
        case .PushNotification: return "pushLocationRequestNotifications"
        case .URLScheme: return "urlSchemeLocationRequestNotifications"
        case .XCallbackURL: return "xCallbackURLLocationRequestNotifications"
        case .AppShortcut: return nil
        case .Visit: return nil
        case .Manual: return nil
        case .Siri: return nil
        case .RegionExit, .RegionEnter, .Unknown: return nil
        case .Launch: return nil
        case .Periodic: return nil
        case .Signaled: return nil
        }
    }

    public func notificationOptionsFor(zoneName: String) -> NotificationOptions {
        var identifier: String?
        let body: String
        let title = L10n.LocationChangeNotification.title
        let shouldNotify = notificationPreferenceKey.flatMap { Current.settingsStore.prefs.bool(forKey: $0) } ?? false

        switch self {
        case .BeaconRegionEnter:
            body = L10n.LocationChangeNotification.BeaconRegionEnter.body(zoneName)
            identifier = "\(zoneName)_beacon_entered"
        case .BeaconRegionExit:
            body = L10n.LocationChangeNotification.BeaconRegionExit.body(zoneName)
            identifier = "\(zoneName)_beacon_exited"
        case .GPSRegionEnter:
            body = L10n.LocationChangeNotification.RegionEnter.body(zoneName)
            identifier = "\(zoneName)_entered"
        case .GPSRegionExit:
            body = L10n.LocationChangeNotification.RegionExit.body(zoneName)
            identifier = "\(zoneName)_exited"
        case .SignificantLocationUpdate:
            body = L10n.LocationChangeNotification.SignificantLocationUpdate.body
            identifier = "sig_change"
        case .BackgroundFetch:
            body = L10n.LocationChangeNotification.BackgroundFetch.body
            identifier = "background_fetch"
        case .PushNotification:
            body = L10n.LocationChangeNotification.PushNotification.body
            identifier = "push_notification"
        case .URLScheme:
            body = L10n.LocationChangeNotification.UrlScheme.body
            identifier = "url_scheme"
        case .XCallbackURL:
            body = L10n.LocationChangeNotification.XCallbackUrl.body
            identifier = "x_callback_url"
        case .AppShortcut:
            body = L10n.LocationChangeNotification.AppShortcut.body
        case .Visit:
            body = L10n.LocationChangeNotification.Visit.body
        case .Manual:
            body = L10n.LocationChangeNotification.Manual.body
        case .Siri:
            body = L10n.LocationChangeNotification.Siri.body
        case .RegionExit, .RegionEnter, .Unknown:
            body = L10n.LocationChangeNotification.Unknown.body
        case .Launch:
            body = L10n.LocationChangeNotification.Launch.body
        case .Periodic:
            body = L10n.LocationChangeNotification.Periodic.body
        case .Signaled:
            body = L10n.LocationChangeNotification.Signaled.body
        }

        return NotificationOptions(shouldNotify: shouldNotify, identifier: identifier, title: title, body: body)
    }
}
