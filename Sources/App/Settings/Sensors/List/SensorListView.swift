import Foundation
import Shared
import SwiftUI

struct SensorListView: View {
    @StateObject private var viewModel = SensorListViewModel()
    @StateObject private var permissionsViewModel = SensorPermissionsViewModel()

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
                AppleLikeListTopRowHeader(
                    image: .motionSensorIcon,
                    title: L10n.SettingsSensors.title,
                    subtitle: L10n.SettingsSensors.body
                )
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
            healthSensorsSection
            if !viewModel.isSearching {
                Section {
                    Toggle(isOn: .init(get: {
                        viewModel.sensors.filter { !Current.sensors.isEnabled(sensor: $0) }.isEmpty
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
                        Current.sensors.isEnabled(sensor: sensor)
                    }, set: { newValue in
                        viewModel.setEnabled(newValue, for: sensor)
                    })) {
                        SensorRow(sensor: sensor, isEnabled: Current.sensors.isEnabled(sensor: sensor))
                    }
                    NavigationLink(destination: SensorDetailView(sensor: sensor)) {
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
        .searchable(
            text: $viewModel.searchTerm,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(L10n.SettingsSensors.Sensors.searchPrompt)
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

    /// Apple Health has too many sensors to mix into the list below, so they get their own screen.
    @ViewBuilder
    private var healthSensorsSection: some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if viewModel.showHealthSection {
            Section(footer: Text(L10n.SettingsSensors.Health.footer)) {
                NavigationLink {
                    HealthSensorListView()
                } label: {
                    HStack {
                        Text(L10n.SettingsSensors.Health.Sensors.title)
                        LabsLabel()
                        Spacer()
                        // Inside the label rather than `.badge`, so the count sits between the
                        // title and the disclosure chevron instead of after it.
                        Text("\(viewModel.enabledHealthSensorCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        #endif
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
        ]
        #if os(iOS) && !targetEnvironment(macCatalyst)
        entries.append(SettingsSearchEntry(L10n.SettingsSensors.Health.header))
        entries.append(SettingsSearchEntry(L10n.SettingsSensors.Health.Sensors.title))
        entries.append(contentsOf: HealthKitMetric.all.map { SettingsSearchEntry($0.name) })
        #endif
        return entries
    }
}
