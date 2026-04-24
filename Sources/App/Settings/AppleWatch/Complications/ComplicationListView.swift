import Shared
import SwiftUI

/// SwiftUI replacement for `ComplicationListViewController`.
struct ComplicationListView: View {
    @StateObject private var viewModel = ComplicationListViewModel()
    @State private var showFamilyPicker = false

    var body: some View {
        List {
            introSection
            manualUpdatesSection
            groupSections
            addSection
        }
        .navigationTitle(L10n.SettingsDetails.Watch.title)
        .sheet(isPresented: $showFamilyPicker) {
            NavigationView {
                ComplicationFamilySelectView(
                    allowMultiple: viewModel.supportsMultipleComplications,
                    currentFamilies: viewModel.currentFamilies,
                    onSaved: { showFamilyPicker = false }
                )
            }
            .navigationViewStyle(.stack)
        }
        .alert(
            L10n.errorLabel,
            isPresented: $viewModel.showError,
            presenting: viewModel.errorMessage
        ) { _ in
            Button(L10n.okLabel, role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Sections

    private var introSection: some View {
        Section {
            Text(L10n.Watch.Configurator.List.description)
                .foregroundColor(.primary)
            Link(destination: URL(string: "https://companion.home-assistant.io/app/ios/apple-watch")!) {
                HStack {
                    Text(L10n.Nfc.List.learnMore)
                    Spacer()
                    Image(systemSymbol: .arrowUpForwardSquare)
                        .font(.caption)
                }
            }
            Text(L10n.Watch.Configurator.Warning.templatingAdmin)
                .foregroundColor(.secondary)
        }
    }

    private var manualUpdatesSection: some View {
        Section {
            HStack {
                Text(L10n.Watch.Configurator.List.ManualUpdates.remaining)
                Spacer()
                Text(viewModel.remainingUpdatesDescription)
                    .foregroundColor(.secondary)
            }
            LoadingButton(
                title: L10n.Watch.Configurator.List.ManualUpdates.manuallyUpdate,
                isLoading: viewModel.isUpdatingComplications
            ) {
                viewModel.updateComplications()
            }
        } header: {
            Text(L10n.Watch.Configurator.List.ManualUpdates.title)
        } footer: {
            Text(L10n.Watch.Configurator.List.ManualUpdates.footer)
        }
    }

    @ViewBuilder
    private var groupSections: some View {
        ForEach(ComplicationGroup.allCases.sorted(), id: \.self) { group in
            if let items = viewModel.complicationsByGroup[group], !items.isEmpty {
                Section {
                    ForEach(items, id: \.identifier) { complication in
                        NavigationLink {
                            ComplicationEditView(
                                config: complication,
                                isNew: false,
                                onSaved: nil
                            )
                        } label: {
                            HStack {
                                Text(complication.Family.shortName)
                                Spacer()
                                Text(complication.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(group.name)
                } footer: {
                    Text(group.description)
                }
            }
        }
    }

    private var addSection: some View {
        Section {
            Button(L10n.addButtonLabel) {
                showFamilyPicker = true
            }
        }
    }
}
