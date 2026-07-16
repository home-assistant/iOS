import Shared
import SwiftUI

struct RemindersSyncAddView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RemindersSyncAddViewModel()

    var body: some View {
        NavigationView {
            Form {
                if viewModel.servers.count > 1 {
                    Section {
                        Picker(L10n.RemindersSync.Add.server, selection: $viewModel.selectedServerId) {
                            ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                                Text(server.info.name).tag(String?.some(server.identifier.rawValue))
                            }
                        }
                    }
                }
                Section {
                    Picker(L10n.RemindersSync.Add.remindersList, selection: $viewModel.selectedReminderListId) {
                        ForEach(viewModel.reminderLists, id: \.calendarIdentifier) { list in
                            Text(list.title).tag(String?.some(list.calendarIdentifier))
                        }
                    }
                    Picker(L10n.RemindersSync.Add.todoList, selection: $viewModel.selectedTodoEntityId) {
                        ForEach(viewModel.todoEntities, id: \.entityId) { entity in
                            Text(entity.name).tag(String?.some(entity.entityId))
                        }
                    }
                }
                Section(footer: Group {
                    if viewModel.isDuplicate {
                        Text(L10n.RemindersSync.Add.duplicateWarning)
                            .foregroundStyle(.red)
                    }
                }) {
                    Picker(L10n.RemindersSync.Add.direction, selection: $viewModel.direction) {
                        ForEach(RemindersSyncDirection.allCases) { direction in
                            Text(direction.localizedTitle).tag(direction)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle(L10n.RemindersSync.Add.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancelLabel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.saveLabel) {
                        if viewModel.save() {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .onChange(of: viewModel.selectedServerId) { _ in
                viewModel.selectedServerChanged()
            }
            .task {
                await viewModel.load()
            }
        }
    }
}

#Preview {
    RemindersSyncAddView()
}
