import Shared
import SwiftUI

/// The choice of what one server receives of the watch's location: the exact fix, only the zone
/// the watch is in, or nothing. Nothing is sent until the user picks exact or zone-only. Picking
/// either asks for location access, re-arms zone monitoring and sends the location straight away.
struct WatchLocationPrivacySection: View {
    let server: Server

    @State private var privacy: ServerLocationPrivacy

    init(server: Server) {
        self.server = server
        self._privacy = State(initialValue: WatchUserDefaults.shared.locationPrivacy(forServer: server.identifier))
    }

    var body: some View {
        Section {
            Picker(selection: Binding(
                get: { privacy },
                set: { newValue in
                    guard newValue != privacy else { return }
                    privacy = newValue
                    WatchUserDefaults.shared.setLocationPrivacy(newValue, forServer: server.identifier)
                    if newValue != .never {
                        Current.locationManager.requestLocationPermission()
                    }
                    Task {
                        if #available(watchOS 10, *) {
                            await WatchZoneMonitor.shared.rearm()
                        }
                        await WatchDeviceReporter.shared.report(trigger: .settingsChange)
                    }
                }
            )) {
                ForEach(ServerLocationPrivacy.allCases, id: \.rawValue) { option in
                    Text(verbatim: option.localizedDescription).tag(option)
                }
            } label: {
                Text(verbatim: L10n.Settings.ConnectionSection.LocationSendType.title)
            }
            .pickerStyle(.inline)
        } footer: {
            Text(verbatim: L10n.Watch.Settings.Location.footer)
        }
    }
}

#Preview {
    NavigationView {
        List {
            WatchLocationPrivacySection(server: ServerFixture.standard)
        }
    }
}
