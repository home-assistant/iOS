#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Lists every Apple Health metric the app can report, grouped the way the Health app groups them.
/// Metrics are opt-in: enabling one here is what makes it eligible for the permission request and for
/// being sent to Home Assistant.
struct HealthSensorListView: View {
    @StateObject private var viewModel = HealthSensorListViewModel()

    var body: some View {
        List {
            requestAccessSection
            enableAllSection
            ForEach(viewModel.visibleCategories, id: \.self) { category in
                Section(category.name) {
                    ForEach(viewModel.metrics(in: category), id: \.uniqueID) { metric in
                        HealthSensorRow(
                            metric: metric,
                            stateDescription: viewModel.stateDescription(for: metric),
                            isEnabled: binding(for: metric)
                        )
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchTerm)
        .navigationTitle(L10n.SettingsSensors.Health.Sensors.title)
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(L10n.SettingsSensors.Health.header),
                message: Text(viewModel.alertMessage ?? ""),
                dismissButton: .default(Text(L10n.okLabel))
            )
        }
    }

    private var requestAccessSection: some View {
        Section(footer: Text(L10n.SettingsSensors.Health.Sensors.footer)) {
            Button {
                Task { await viewModel.requestAuthorization() }
            } label: {
                Text(L10n.SettingsSensors.Health.requestAccess)
            }
            .disabled(!viewModel.isHealthKitAvailable)
        }
    }

    private var enableAllSection: some View {
        Section {
            Toggle(isOn: .init(
                get: { viewModel.areAllEnabled },
                set: { viewModel.setAllEnabled($0) }
            )) {
                Text(L10n.SettingsSensors.Health.Sensors.enableAll)
            }
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
