import Shared
import SwiftUI

struct NotificationDebugNotificationsView: View {
    private struct Toggle: Identifiable {
        let id: String
        let title: String
    }

    private let toggles: [Toggle] = [
        .init(id: "enterNotifications", title: L10n.SettingsDetails.Location.Notifications.Enter.title),
        .init(id: "exitNotifications", title: L10n.SettingsDetails.Location.Notifications.Exit.title),
        .init(id: "beaconEnterNotifications", title: L10n.SettingsDetails.Location.Notifications.BeaconEnter.title),
        .init(id: "beaconExitNotifications", title: L10n.SettingsDetails.Location.Notifications.BeaconExit.title),
        .init(
            id: "significantLocationChangeNotifications",
            title: L10n.SettingsDetails.Location.Notifications.LocationChange.title
        ),
        .init(
            id: "backgroundFetchLocationChangeNotifications",
            title: L10n.SettingsDetails.Location.Notifications.BackgroundFetch.title
        ),
        .init(
            id: "pushLocationRequestNotifications",
            title: L10n.SettingsDetails.Location.Notifications.PushNotification.title
        ),
        .init(
            id: "urlSchemeLocationRequestNotifications",
            title: L10n.SettingsDetails.Location.Notifications.UrlScheme.title
        ),
        .init(
            id: "xCallbackURLLocationRequestNotifications",
            title: L10n.SettingsDetails.Location.Notifications.XCallbackUrl.title
        ),
    ]

    var body: some View {
        List {
            Section {
                ForEach(toggles) { toggle in
                    PrefsToggleRow(key: toggle.id, title: toggle.title)
                }
            }
        }
        .navigationTitle(L10n.SettingsDetails.Location.Notifications.header)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrefsToggleRow: View {
    let key: String
    let title: String

    @State private var value: Bool

    init(key: String, title: String) {
        self.key = key
        self.title = title
        _value = State(initialValue: prefs.bool(forKey: key))
    }

    var body: some View {
        SwiftUI.Toggle(isOn: Binding(
            get: { value },
            set: { newValue in
                value = newValue
                prefs.set(newValue, forKey: key)
            }
        )) {
            Text(title)
        }
    }
}
