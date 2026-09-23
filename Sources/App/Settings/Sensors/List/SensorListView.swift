import Foundation
import Shared
import SwiftUI

/// Settings → Sensors, and — when the install has more than one server — each server's own copy of
/// it, reached from the list of servers this screen shows instead of the sensors.
///
/// Sensors are chosen per server, so the toggles below always belong to exactly one of them. What
/// is device-wide rather than per server — the update interval, the permissions sensors depend on
/// — stays on the root screen, where it is decided once.
struct SensorListView: View {
    @StateObject private var viewModel: SensorListViewModel
    @StateObject private var permissionsViewModel = SensorPermissionsViewModel()

    /// Whether this is one server's copy of the screen rather than the root, which is what decides
    /// the header and whether the device-wide settings appear.
    private let isServerScoped: Bool

    /// The root screen, which scopes itself to the only server when there is one.
    init(viewModel: SensorListViewModel? = nil) {
        self.isServerScoped = false
        self._viewModel = .init(wrappedValue: viewModel ?? SensorListViewModel())
    }

    /// One server's sensors, pushed from the list of servers on the root screen.
    init(server: Server, viewModel: SensorListViewModel? = nil) {
        self.isServerScoped = true
        self._viewModel = .init(wrappedValue: viewModel ?? SensorListViewModel(server: server))
    }

    private let periodicOptions: [TimeInterval?] = {
        var options: [TimeInterval?] = [nil, 20, 60, 120, 300, 600, 900, 1800, 3600]
        if Current.appConfiguration == .debug {
            options.insert(contentsOf: [2, 5], at: 1)
        }
        return options
    }()

    var body: some View {
        List {
            if !viewModel.isSearching {
                if let server = viewModel.server, isServerScoped {
                    AppleLikeListTopRowHeader(
                        image: .motionSensorIcon,
                        title: server.info.name,
                        subtitle: L10n.SettingsSensors.Servers.serverBody
                    )
                } else {
                    AppleLikeListTopRowHeader(
                        image: .motionSensorIcon,
                        title: L10n.SettingsSensors.title,
                        subtitle: L10n.SettingsSensors.body
                    )
                }

                if !isServerScoped {
                    Section(
                        header: Text(L10n.SettingsSensors.PeriodicUpdate.foregroundHeader),
                        footer: Text(periodicUpdateFooter)
                    ) {
                        Picker(
                            selection: $viewModel.periodicUpdateInterval,
                            label: Text(L10n.SettingsSensors.PeriodicUpdate.title)
                        ) {
                            ForEach(periodicOptions, id: \.self) { option in
                                Text(periodicUpdateDisplayText(for: option)).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: viewModel.periodicUpdateInterval) { newValue in
                            viewModel.setPeriodicUpdateInterval(newValue)
                        }
                    }

                    if !permissionsViewModel.availablePermissions.isEmpty {
                        Section {
                            NavigationLink {
                                SensorPermissionsView()
                            } label: {
                                HStack {
                                    Text(L10n.SettingsSensors.Permissions.header)
                                    Spacer()
                                    if permissionsViewModel.notDeterminedCount > 0 {
                                        Text("\(permissionsViewModel.notDeterminedCount)")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(.orange, in: Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Each server picks its own sensors, so with more than one there is nothing sensible to
            // toggle on this screen — it lists the servers, and the toggles live one step in.
            if !isServerScoped, !viewModel.selectableServers.isEmpty {
                Section {
                    ForEach(viewModel.filteredServers, id: \.identifier) { server in
                        NavigationLink {
                            SensorListView(server: server)
                        } label: {
                            Text(server.info.name)
                        }
                    }
                } header: {
                    Text(L10n.SettingsSensors.Servers.header)
                } footer: {
                    Text(L10n.SettingsSensors.Servers.footer)
                }
            }

            if let server = viewModel.server {
                #if os(iOS) && !targetEnvironment(macCatalyst)
                // Apple Health has too many sensors to mix into the list below, so they get their
                // own screen.
                if viewModel.showHealthSection {
                    Section(footer: Text(L10n.SettingsSensors.Health.footer)) {
                        NavigationLink {
                            HealthSensorListView(server: server)
                        } label: {
                            HStack {
                                Text(L10n.SettingsSensors.Health.Sensors.title)
                                LabsLabel()
                                Spacer()
                                Text("\(viewModel.enabledHealthSensorCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                #endif

                if !viewModel.isSearching {
                    Section {
                        Toggle(isOn: .init(get: {
                            viewModel.allSensorsEnabled
                        }, set: { newValue in
                            viewModel.updateAllSensors(isEnabled: newValue)
                        })) {
                            Text(L10n.SettingsSensors.Sensors.enableAll)
                        }
                    } header: {
                        Text(L10n.SettingsSensors.Sensors.header)
                    } footer: {
                        if let lastUpdate = viewModel.lastUpdateDate {
                            Text("\(L10n.SettingsSensors.LastUpdated.prefix) ") +
                                Text(lastUpdate, style: .date) +
                                Text(" ") +
                                Text(lastUpdate, style: .time)
                        }
                    }
                }

                ForEach(viewModel.filteredSensors, id: \.UniqueID) { sensor in
                    Section {
                        Toggle(isOn: .init(get: {
                            viewModel.isEnabled(sensor)
                        }, set: { newValue in
                            viewModel.setEnabled(newValue, for: sensor)
                        })) {
                            SensorRow(sensor: sensor, isEnabled: viewModel.isEnabled(sensor))
                        }
                        NavigationLink(destination: SensorDetailView(sensor: sensor, server: server)) {
                            Text(L10n.SettingsSensors.Sensors.configure)
                        }
                    }
                }

                if viewModel.isSearching, viewModel.filteredSensors.isEmpty {
                    Section {
                        Text(L10n.SettingsSensors.Sensors.noResults)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .searchable(
            text: $viewModel.searchTerm,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(searchPrompt)
        )
        .onAppear {
            permissionsViewModel.update()
            viewModel.refresh()
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(L10n.SettingsSensors.LoadingError.title),
                message: Text(viewModel.alertMessage ?? ""),
                primaryButton: .default(Text(L10n.retryLabel)) {
                    viewModel.refresh()
                },
                secondaryButton: .cancel(Text(L10n.cancelLabel))
            )
        }
        .listTopContentMargin()
    }

    /// The root screen of an install with several servers lists those rather than sensors, so that
    /// is what its search field looks through.
    private var searchPrompt: String {
        viewModel.server == nil
            ? L10n.SettingsSensors.Servers.searchPrompt
            : L10n.SettingsSensors.Sensors.searchPrompt
    }

    /// On Mac the periodic update also runs while the app is in the background, everywhere else
    /// the interval only applies while the app is on screen.
    private var periodicUpdateFooter: String {
        PeriodicUpdateManager.supportsBackgroundPeriodicUpdates
            ? L10n.SettingsSensors.PeriodicUpdate.descriptionMac
            : L10n.SettingsSensors.PeriodicUpdate.descriptionForeground
    }

    private func periodicUpdateDisplayText(for value: TimeInterval?) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        switch value {
        case .none:
            return L10n.SettingsSensors.PeriodicUpdate.off
        case let .some(interval):
            return formatter.string(from: interval) ?? ""
        }
    }
}

#Preview {
    NavigationView {
        SensorListView()
    }
}

extension SensorListView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        var entries = [
            SettingsSearchEntry(L10n.SettingsSensors.PeriodicUpdate.title),
            SettingsSearchEntry(L10n.SettingsSensors.Permissions.header),
            SettingsSearchEntry(L10n.SettingsDetails.Location.MotionPermission.title),
            SettingsSearchEntry(L10n.SettingsSensors.FocusPermission.title),
            SettingsSearchEntry(L10n.SettingsSensors.Sensors.header),
            SettingsSearchEntry(L10n.SettingsSensors.Sensors.enableAll),
            SettingsSearchEntry(L10n.SettingsSensors.Servers.header),
        ]
        #if os(iOS) && !targetEnvironment(macCatalyst)
        entries.append(SettingsSearchEntry(L10n.SettingsSensors.Health.header))
        entries.append(SettingsSearchEntry(L10n.SettingsSensors.Health.Sensors.title))
        entries.append(contentsOf: HealthKitMetric.all.map { SettingsSearchEntry($0.name) })
        #endif
        return entries
    }
}
