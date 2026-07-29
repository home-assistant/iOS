#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Lists every Apple Health metric the app can report, grouped the way the Health app groups them.
/// Metrics are opt-in: turning one on here is what makes it eligible for the permission request and
/// for being sent to Home Assistant.
struct HealthSensorListView: View {
    @StateObject private var viewModel = HealthSensorListViewModel()

    var body: some View {
        List {
            if !viewModel.isSearching {
                Section(footer: Text(L10n.SettingsSensors.Health.Sensors.footer)) {
                    Toggle(isOn: .init(
                        get: { viewModel.areAllEnabled },
                        set: { viewModel.setAllEnabled($0) }
                    )) {
                        Text(L10n.SettingsSensors.Health.Sensors.enableAll)
                    }
                }
            }
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
