import FirebaseMessaging
import Shared
import SwiftUI

struct PrivacyView: View {
    @State private var messaging: Bool = Current.settingsStore.privacy.messaging
    @State private var alerts: Bool = Current.settingsStore.privacy.alerts
    @State private var crashes: Bool = Current.settingsStore.privacy.crashes
    @State private var analytics: Bool = Current.settingsStore.privacy.analytics

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .lockIcon,
                title: L10n.SettingsDetails.Privacy.title,
                subtitle: L10n.SettingsDetails.Privacy.body
            )
            Section(footer: Text(L10n.SettingsDetails.Privacy.Messaging.description)) {
                Toggle(L10n.SettingsDetails.Privacy.Messaging.title, isOn: $messaging)
                    .onChange(of: messaging) { value in
                        Current.settingsStore.privacy.messaging = value
                        Messaging.messaging().isAutoInitEnabled = value
                    }
            }
            Section(footer: Text(L10n.SettingsDetails.Privacy.Alerts.description)) {
                Toggle(L10n.SettingsDetails.Privacy.Alerts.title, isOn: $alerts)
                    .onChange(of: alerts) { value in
                        Current.settingsStore.privacy.alerts = value
                    }
            }
            if Current.crashReporter.hasCrashReporter {
                Section(footer: Text(L10n.SettingsDetails.Privacy.CrashReporting.description)) {
                    Toggle(L10n.SettingsDetails.Privacy.CrashReporting.title, isOn: $crashes)
                        .onChange(of: crashes) { value in
                            Current.settingsStore.privacy.crashes = value
                        }
                }
            }
            if Current.crashReporter.hasAnalytics {
                Section(footer: Text(L10n.SettingsDetails.Privacy.Analytics.genericDescription)) {
                    Toggle(L10n.SettingsDetails.Privacy.Analytics.genericTitle, isOn: $analytics)
                        .onChange(of: analytics) { value in
                            Current.settingsStore.privacy.analytics = value
                        }
                }
            }
        }
        .removeListsPaddingWithAppleLikeHeader()
    }
}

#Preview {
    PrivacyView()
}
