import Shared
import SwiftUI

/// SwiftUI replacement for `ComplicationListViewController`.
struct ComplicationListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ComplicationListViewModel()
    @State private var showFamilyPicker = false
    @State private var showDeleteAllConfirmation = false

    var body: some View {
        List {
            groupSections
            #if DEBUG
            // Creating new legacy (ClockKit-era) complications is retained for debugging only; users
            // build complications through the modern entity/template builder on the root screen.
            addSection
            #endif
            deleteAllSection
        }
        .navigationTitle(Text(L10n.Watch.Complications.Legacy.title))
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

    private var deleteAllSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAllConfirmation = true
            } label: {
                Text(L10n.Watch.Complications.Legacy.deleteAll)
            }
            .confirmationDialog(
                L10n.Watch.Complications.Legacy.deleteAllConfirm,
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    viewModel.deleteAll()
                    // Nothing left to configure here; return to the root, where the legacy entry hides.
                    dismiss()
                } label: {
                    Text(L10n.Watch.Complications.Legacy.deleteAll)
                }
                Button(role: .cancel) {} label: { Text(L10n.cancelLabel) }
            }
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

    #if DEBUG
    private var addSection: some View {
        Section {
            Button(L10n.addButtonLabel) {
                showFamilyPicker = true
            }
        }
    }
    #endif
}

#Preview("Legacy complications") {
    NavigationView { ComplicationListView() }
}
