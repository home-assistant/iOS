import Shared
import SwiftUI

/// Developer-only options, reached from Settings → Troubleshooting. Presents a warning on entry:
/// these switches change how magic items execute and are meant to be used under a developer's
/// guidance while debugging.
struct WatchDeveloperSettingsView: View {
    @State private var verboseExecution = WatchUserDefaults.shared.verboseItemExecution
    @State private var showIPhoneUnreachableIcon = WatchUserDefaults.shared.showIPhoneUnreachableIcon
    @State private var complicationRefreshNotifications = WatchUserDefaults.shared
        .complicationRefreshNotificationsEnabled
    /// True on entry so the warning alert shows as soon as the screen is pushed.
    @State private var showWarning = true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $verboseExecution) {
                    Text(verbatim: L10n.Watch.Settings.Developer.VerboseExecution.title)
                }
                .onChange(of: verboseExecution) { newValue in
                    WatchUserDefaults.shared.verboseItemExecution = newValue
                }
            } footer: {
                Text(verbatim: L10n.Watch.Settings.Developer.VerboseExecution.footer)
            }

            Section {
                Toggle(isOn: $showIPhoneUnreachableIcon) {
                    Text(verbatim: L10n.Watch.Settings.Developer.IphoneUnreachableIcon.title)
                }
                .onChange(of: showIPhoneUnreachableIcon) { newValue in
                    WatchUserDefaults.shared.showIPhoneUnreachableIcon = newValue
                }
            } footer: {
                Text(verbatim: L10n.Watch.Settings.Developer.IphoneUnreachableIcon.footer)
            }

            Section {
                Toggle(isOn: $complicationRefreshNotifications) {
                    Text(verbatim: L10n.Watch.Settings.Developer.ComplicationRefreshNotifications.title)
                }
                .onChange(of: complicationRefreshNotifications) { newValue in
                    WatchUserDefaults.shared.complicationRefreshNotificationsEnabled = newValue
                }
            } footer: {
                Text(verbatim: L10n.Watch.Settings.Developer.ComplicationRefreshNotifications.footer)
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.Developer.title))
        .alert(
            Text(verbatim: L10n.Watch.Settings.Developer.Warning.title),
            isPresented: $showWarning
        ) {
            Button(role: .cancel) {} label: { Text(verbatim: L10n.okLabel) }
        } message: {
            Text(verbatim: L10n.Watch.Settings.Developer.Warning.message)
        }
    }
}

#Preview {
    NavigationView {
        WatchDeveloperSettingsView()
    }
}
