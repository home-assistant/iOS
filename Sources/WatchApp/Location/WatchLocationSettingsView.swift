import Combine
import CoreLocation
import SFSafeSymbols
import Shared
import SwiftUI

/// What the watch reports of its own location to Home Assistant, which is what its device tracker
/// shows. Chosen per server, as on the iPhone: with one server the choice is right here, and with
/// several this screen lists the servers and the choice lives one step in.
struct WatchLocationSettingsView: View {
    @StateObject private var viewModel = WatchSensorsSettingsViewModel()
    @State private var permissionDenied = false
    /// Whether location access was granted when last seen, so only a grant that just happened
    /// triggers a report.
    @State private var permissionGranted = false

    var body: some View {
        List {
            if viewModel.servers.isEmpty {
                Section {
                    Text(verbatim: L10n.Watch.Settings.noServers)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.servers.count == 1, let server = viewModel.servers.first {
                // Keyed by server so a sync that replaces the only server doesn't carry its choice over.
                WatchLocationPrivacySection(server: server)
                    .id(server.identifier.rawValue)
            } else {
                Section {
                    ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                        NavigationLink {
                            WatchServerLocationSettingsView(server: server)
                        } label: {
                            Label {
                                Text(verbatim: server.info.name)
                            } icon: {
                                Image(systemSymbol: .network)
                            }
                        }
                    }
                } footer: {
                    Text(verbatim: L10n.Watch.Settings.Location.serversFooter)
                }
            }

            if permissionDenied {
                Section {
                    Label {
                        Text(verbatim: L10n.Watch.Settings.Location.permissionDenied)
                            .font(.footnote)
                    } icon: {
                        Image(systemSymbol: .exclamationmarkTriangleFill)
                    }
                    .foregroundStyle(.yellow)
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.Location.title))
        .onAppear {
            viewModel.reload()
        }
        .task {
            let status = await Self.permissionStatus()
            permissionDenied = status == .denied || status == .restricted
            permissionGranted = status == .authorizedAlways || status == .authorizedWhenInUse
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .locationPermissionDidChange).receive(on: DispatchQueue.main)
        ) { notification in
            let state = notification.userInfo?["permissionState"] as? LocationPermissionState
            permissionDenied = state == .denied || state == .restricted
            let granted = state == .authorizedWhenInUse || state == .authorizedAlways
            // A choice made while the permission prompt was up had no fix to send; send it now.
            // Asking again once access is granted posts the same state, which needs no new report.
            if granted, !permissionGranted {
                Task {
                    await WatchDeviceReporter.shared.report(trigger: .settingsChange)
                }
            }
            permissionGranted = granted
        }
    }

    /// `authorizationStatus` performs synchronous XPC to locationd, so it's read off the main thread.
    private static func permissionStatus() async -> CLAuthorizationStatus {
        await Task.detached {
            Current.location.permissionStatus()
        }.value
    }
}

#Preview {
    NavigationView {
        WatchLocationSettingsView()
    }
}
