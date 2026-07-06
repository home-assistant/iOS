import Shared
import SwiftUI

struct NotificationSnoozeActionsView: View {
    @StateObject private var viewModel = NotificationSnoozeActionsViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        List {
            Section {
                ForEach(viewModel.actions) { action in
                    row(for: action)
                }
                .onMove { indices, newOffset in
                    viewModel.move(from: indices, to: newOffset)
                }
                .onDelete { indexSet in
                    viewModel.delete(at: indexSet)
                }

                Button {
                    showingAddSheet = true
                } label: {
                    Label(L10n.addButtonLabel, systemSymbol: .plus)
                }
            } footer: {
                Text(L10n.SettingsDetails.Notifications.SnoozeActions.footer)
                    + Text(verbatim: "\n\n")
                    + Text(L10n.SettingsDetails.Notifications.SnoozeActions.prefixFooter)
            }
        }
        .navigationTitle(L10n.SettingsDetails.Notifications.SnoozeActions.header)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.load()
        }
        .sheet(isPresented: $showingAddSheet) {
            NotificationSnoozeActionAddView(existingMinutes: Set(viewModel.actions.map(\.minutes))) { minutes in
                viewModel.add(minutes: minutes)
            }
            .presentationDetents([.medium])
        }
    }

    private func row(for action: NotificationSnoozeAction) -> some View {
        Toggle(isOn: Binding(
            get: { action.isEnabled },
            set: { viewModel.setEnabled($0, for: action) }
        )) {
            Text(action.title)
        }
    }
}

private struct NotificationSnoozeActionAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 10
    let existingMinutes: Set<Int>
    let onAdd: (Int) -> Void

    private var isDuplicate: Bool {
        existingMinutes.contains(minutes)
    }

    private var durationLabel: String {
        guard minutes >= 60 else {
            return L10n.SettingsDetails.Notifications.SnoozeActions.AddSheet.minutesLabel(minutes)
        }

        let hours = minutes / 60
        let remainder = minutes % 60

        switch (hours, remainder) {
        case (1, 0):
            return L10n.SettingsDetails.Notifications.SnoozeActions.AddSheet.durationHour
        case (_, 0):
            return L10n.SettingsDetails.Notifications.SnoozeActions.AddSheet.durationHours(hours)
        case (1, _):
            return L10n.SettingsDetails.Notifications.SnoozeActions.AddSheet.durationHourMinutes(remainder)
        default:
            return L10n.SettingsDetails.Notifications.SnoozeActions.AddSheet.durationHoursMinutes(hours, remainder)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Stepper(value: $minutes, in: 5 ... 1440, step: 5) {
                        Text(durationLabel)
                    }
                } footer: {
                    if isDuplicate {
                        Text(L10n.SettingsDetails.Notifications.SnoozeActions.AddSheet.duplicateWarning)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.SettingsDetails.Notifications.SnoozeActions.AddSheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancelLabel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.addButtonLabel) {
                        onAdd(minutes)
                        dismiss()
                    }
                    .disabled(isDuplicate)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

final class NotificationSnoozeActionsViewModel: ObservableObject {
    @Published var actions: [NotificationSnoozeAction] = []

    func load() {
        actions = NotificationSnoozeAction.all()
    }

    func setEnabled(_ isEnabled: Bool, for action: NotificationSnoozeAction) {
        var updated = action
        updated.isEnabled = isEnabled
        NotificationSnoozeAction.save(updated)
        load()
    }

    func move(from source: IndexSet, to destination: Int) {
        var reordered = actions
        reordered.move(fromOffsets: source, toOffset: destination)
        NotificationSnoozeAction.reorder(reordered.map(\.id))
        load()
    }

    func delete(at offsets: IndexSet) {
        offsets.map { actions[$0].id }.forEach(NotificationSnoozeAction.delete(id:))
        load()
    }

    func add(minutes: Int) {
        guard !actions.contains(where: { $0.minutes == minutes }) else { return }

        let nextSortOrder = (actions.map(\.sortOrder).max() ?? -1) + 1
        NotificationSnoozeAction.save(NotificationSnoozeAction(minutes: minutes, sortOrder: nextSortOrder))
        load()
    }
}
