import Shared
import SwiftUI

/// Developer-only options, reached from Settings → Troubleshooting. Presents a warning on entry:
/// these switches change how magic items execute and are meant to be used under a developer's
/// guidance while debugging.
struct WatchDeveloperSettingsView: View {
    @State private var verboseExecution = WatchUserDefaults.shared.verboseItemExecution
    @State private var showIPhoneUnreachableIcon = WatchUserDefaults.shared.showIPhoneUnreachableIcon
    @State private var directDatabaseSync = WatchUserDefaults.shared.directDatabaseSyncEnabled
    @State private var directSyncAudioProbe = WatchUserDefaults.shared.directSyncAudioSessionProbeEnabled
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
                Toggle(isOn: $directDatabaseSync) {
                    Text(verbatim: L10n.Watch.Settings.Developer.DirectSync.title)
                }
                .onChange(of: directDatabaseSync) { newValue in
                    WatchUserDefaults.shared.directDatabaseSyncEnabled = newValue
                    if newValue {
                        // Populate immediately so the effect of enabling it is visible.
                        Task { await Current.watchDirectDatabaseSync.syncAll(force: true) }
                    }
                }
            } footer: {
                Text(verbatim: L10n.Watch.Settings.Developer.DirectSync.footer)
            }

            if directDatabaseSync {
                Section {
                    Toggle(isOn: $directSyncAudioProbe) {
                        Text(verbatim: L10n.Watch.Settings.Developer.AudioProbe.title)
                    }
                    .onChange(of: directSyncAudioProbe) { newValue in
                        WatchUserDefaults.shared.directSyncAudioSessionProbeEnabled = newValue
                        if newValue {
                            // Re-run so the socket attempt happens inside the audio window.
                            Task { await Current.watchDirectDatabaseSync.syncAll(force: true) }
                        }
                    }
                } footer: {
                    Text(verbatim: L10n.Watch.Settings.Developer.AudioProbe.footer)
                }
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
