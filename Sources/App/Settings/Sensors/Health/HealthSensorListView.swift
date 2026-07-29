#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Lists every Apple Health metric the app can report, grouped the way the Health app groups them.
/// Metrics are opt-in: turning one on here is what makes it eligible for the permission request and
/// for being sent to Home Assistant.
struct HealthSensorListView: View {
    @StateObject private var viewModel = HealthSensorListViewModel()
    @State private var showEnableAllConfirmation = false

    var body: some View {
        List {
            if !viewModel.isSearching {
                Section(footer: Text(L10n.SettingsSensors.Health.Sensors.footer)) {
                    Toggle(isOn: .init(
                        get: { viewModel.areAllEnabled },
                        set: { isOn in
                            if isOn {
                                showEnableAllConfirmation = true
                            } else {
                                viewModel.setAllEnabled(false)
                            }
                        }
                    )) {
                        Text(L10n.SettingsSensors.Health.Sensors.enableAll)
                    }
                    .alert(
                        L10n.SettingsSensors.Health.Sensors.EnableAll.Confirmation.title(viewModel.totalSensorCount),
                        isPresented: $showEnableAllConfirmation
                    ) {
                        Button(L10n.cancelLabel, role: .cancel) {}
                        Button(L10n.SettingsSensors.Health.Sensors.EnableAll.Confirmation.confirm) {
                            viewModel.setAllEnabled(true)
                            Task { await viewModel.requestAuthorization() }
                        }
                    }
                    Button {
                        Task { await viewModel.requestAuthorization() }
                    } label: {
                        Text(L10n.SettingsSensors.Health.requestAccess)
                    }
                    .disabled(!viewModel.isHealthKitAvailable)
                }
            }
            ForEach(viewModel.visibleCategories, id: \.self) { category in
                Section {
                    ForEach(viewModel.metrics(in: category), id: \.uniqueID) { metric in
                        HealthSensorRow(
                            metric: metric,
                            stateDescription: viewModel.stateDescription(for: metric),
                            isEnabled: binding(for: metric)
                        )
                    }
                } header: {
                    sectionHeader(for: category)
                }
            }
            if viewModel.isSearching, viewModel.visibleCategories.isEmpty {
                Text(L10n.SettingsSensors.Sensors.noResults)
                    .foregroundStyle(.secondary)
            }
        }
        .searchable(
            text: $viewModel.searchTerm,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(L10n.SettingsSensors.Sensors.searchPrompt)
        )
        .navigationTitle(L10n.SettingsSensors.Health.Sensors.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.refreshSensors()
                } label: {
                    Image(systemSymbol: .arrowClockwise)
                }
                .accessibilityLabel(L10n.SettingsSensors.Health.reload)
            }
        }
        .alert(L10n.errorLabel, isPresented: $viewModel.showAlert) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    @ViewBuilder
    private func sectionHeader(for category: HealthKitMetricCategory) -> some View {
        HStack {
            Text(category.name.uppercased())
            Spacer()
            Button(L10n.SettingsSensors.Health.Sensors.enableAllSection) {
                viewModel.enableAll(in: category)
            }
            .textCase(nil)
            .font(DesignSystem.Font.footnote)
            .tint(.haPrimary)
        }
    }

    private func binding(for metric: HealthKitMetric) -> Binding<Bool> {
        .init(
            get: { viewModel.isEnabled(metric) },
            set: { viewModel.setEnabled($0, for: metric) }
        )
    }
}

#Preview {
    NavigationView {
        HealthSensorListView()
    }
}
#endif
