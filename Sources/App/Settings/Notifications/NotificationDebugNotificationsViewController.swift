import Eureka
import RealmSwift
import Shared

class NotificationDebugNotificationsViewController: HAFormViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.SettingsDetails.Location.Notifications.header

        form +++ Section()

            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.Enter.title
                $0.value = prefs.bool(forKey: "enterNotifications")
            }.onChange({ row in
                if let val = row.value {
                    prefs.set(val, forKey: "enterNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.Exit.title
                $0.value = prefs.bool(forKey: "exitNotifications")
            }.onChange({ row in
                if let val = row.value {
                    prefs.set(val, forKey: "exitNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.BeaconEnter.title
                $0.value = prefs.bool(forKey: "beaconEnterNotifications")
            }.onChange({ row in
                if let val = row.value {
                    prefs.set(val, forKey: "beaconEnterNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.BeaconExit.title
                $0.value = prefs.bool(forKey: "beaconExitNotifications")
            }.onChange({ row in
                if let val = row.value {
                    prefs.set(val, forKey: "beaconExitNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.LocationChange.title
                $0.value = prefs.bool(forKey: "significantLocationChangeNotifications")
            }.onChange({ row in
                if let val = row.value {
                    prefs.set(val, forKey: "significantLocationChangeNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.BackgroundFetch.title
                $0.value = prefs.bool(forKey: "backgroundFetchLocationChangeNotifications")
            }.onChange({ row in
                if let val = row.value {
                    prefs.set(val, forKey: "backgroundFetchLocationChangeNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.PushNotification.title
                $0.value = prefs.bool(forKey: "pushLocationRequestNotifications")
            }.onChange({ row in
                if let val = row.value {
                    prefs.set(val, forKey: "pushLocationRequestNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.UrlScheme.title
                $0.value = prefs.bool(forKey: "urlSchemeLocationRequestNotifications")
            }.onChange({ row in
                if let val = row.value {
                    prefs.set(val, forKey: "urlSchemeLocationRequestNotifications")
                }
            })
            <<< SwitchRow {
                $0.title = L10n.SettingsDetails.Location.Notifications.XCallbackUrl.title
                $0.value = prefs.bool(forKey: "xCallbackURLLocationRequestNotifications")
            }.onChange({ row in
                if let val = row.value {
                    prefs.set(val, forKey: "xCallbackURLLocationRequestNotifications")
                }
            })
    }
}
