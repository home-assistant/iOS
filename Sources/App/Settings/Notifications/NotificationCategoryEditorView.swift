import RealmSwift
import Shared
import SwiftUI
import UserNotifications

/// SwiftUI replacement for `NotificationCategoryConfigurator`.
///
/// Edits a `NotificationCategory`, its hidden-preview placeholder, category
/// summary format, and the list of `NotificationAction`s. Supports
/// reorder/insert/delete for actions (capped at `maxActionsForCategory`), a
/// live YAML service-call preview, read-only mode when the category is
/// server-controlled, a help link in the toolbar and a preview-notification
/// action.
struct NotificationCategoryEditorView: View {
    let existingCategory: NotificationCategory?
    let onDismiss: (NotificationCategory?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var identifier: String
    @State private var hiddenPreviewsPlaceholder: String
    @State private var categorySummaryFormat: String
    @State private var actions: [NotificationAction]

    @State private var editingAction: NotificationAction?
    @State private var showingNewAction = false
    @State private var showValidationAlert = false

    private let isNewCategory: Bool
    private let isServerControlled: Bool
    private let category: NotificationCategory
    private let maxActionsForCategory = 10

    init(
        category: NotificationCategory?,
        onDismiss: @escaping (NotificationCategory?) -> Void
    ) {
        self.existingCategory = category
        self.onDismiss = onDismiss

        let resolved = category ?? NotificationCategory()
        self.category = resolved
        self.isNewCategory = (category == nil)
        self.isServerControlled = resolved.isServerControlled

        _name = State(initialValue: resolved.Name)
        _identifier = State(initialValue: resolved.Identifier)

        let placeholderDefault = L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.default
        let placeholder = resolved.HiddenPreviewsBodyPlaceholder ?? ""
        _hiddenPreviewsPlaceholder = State(
            initialValue: placeholder.isEmpty ? placeholderDefault : placeholder
        )

        let summaryDefault = L10n.NotificationsConfigurator.Category.Rows.CategorySummary.default
        let summary = resolved.CategorySummaryFormat ?? ""
        _categorySummaryFormat = State(
            initialValue: summary.isEmpty ? summaryDefault : summary
        )

        _actions = State(initialValue: Array(resolved.Actions))
    }

    var body: some View {
        Form {
            settingsSection

            if !isServerControlled {
                hiddenPreviewSection
                categorySummarySection
            }

            actionsSection

            YamlPreviewSection(
                header: L10n.NotificationsConfigurator.Category.ExampleCall.title,
                yaml: yamlPreview
            )
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingNewAction) {
            editorSheet(for: nil)
        }
        .sheet(item: $editingAction) { action in
            editorSheet(for: action)
        }
        .alert(L10n.errorLabel, isPresented: $showValidationAlert) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(L10n.NotificationsConfigurator.Settings.footer)
        }
    }

    // MARK: - Sections

    private var settingsSection: some View {
        Section(
            header: Text(L10n.NotificationsConfigurator.Settings.header),
            footer: Text(settingsFooter)
        ) {
            HStack {
                Text(L10n.NotificationsConfigurator.Category.Rows.Name.title)
                Spacer()
                TextField("", text: $name)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(name.isEmpty ? .red : .primary)
                    .disabled(isServerControlled)
            }

            NotificationIdentifierTextField(
                title: L10n.NotificationsConfigurator.identifier,
                text: $identifier,
                uppercaseOnly: false,
                isDisabled: isServerControlled || !isNewCategory
            )
        }
    }

    private var hiddenPreviewSection: some View {
        Section(
            header: Text(L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.header),
            footer: Text(L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.footer)
        ) {
            TextEditor(text: $hiddenPreviewsPlaceholder)
                .frame(minHeight: 80)
        }
    }

    private var categorySummarySection: some View {
        Section(
            header: Text(L10n.NotificationsConfigurator.Category.Rows.CategorySummary.header),
            footer: Text(L10n.NotificationsConfigurator.Category.Rows.CategorySummary.footer)
        ) {
            TextEditor(text: $categorySummaryFormat)
                .frame(minHeight: 80)
        }
    }

    private var actionsSection: some View {
        Section(
            header: Text(L10n.NotificationsConfigurator.Category.Rows.Actions.header),
            footer: Text(isServerControlled ? "" : L10n.NotificationsConfigurator.Category.Rows.Actions.footer)
        ) {
            ForEach(actions, id: \.uuid) { action in
                Button {
                    editingAction = action
                } label: {
                    HStack {
                        Text(action.Title.isEmpty ? action.Identifier : action.Title)
                            .foregroundColor(.primary)
                        Spacer()
                        if !isServerControlled {
                            Image(systemSymbol: .chevronRight)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(isServerControlled)
            }
            .onDelete(perform: isServerControlled ? nil : deleteActions)
            .onMove(perform: isServerControlled ? nil : moveActions)

            if !isServerControlled, actions.count < maxActionsForCategory {
                Button {
                    showingNewAction = true
                } label: {
                    Label(L10n.addButtonLabel, systemSymbol: .plus)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !isServerControlled {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancelLabel) {
                    onDismiss(nil)
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.saveLabel) {
                    if validate() {
                        save()
                    } else {
                        showValidationAlert = true
                    }
                }
            }
        }

        ToolbarItem(placement: .bottomBar) {
            Button {
                openHelp()
            } label: {
                Image(systemSymbol: .questionmarkCircle)
            }
        }

        ToolbarItem(placement: .bottomBar) {
            Spacer()
        }

        ToolbarItem(placement: .bottomBar) {
            Button {
                triggerPreviewNotification()
            } label: {
                Image(systemSymbol: .eye)
            }
            .disabled(identifier.isEmpty)
        }
    }

    // MARK: - Derived values

    private var navigationTitle: String {
        if isNewCategory {
            return L10n.NotificationsConfigurator.Category.NavigationBar.title
        }
        return name.isEmpty ? category.Name : name
    }

    private var settingsFooter: String {
        if isServerControlled {
            return ""
        } else if isNewCategory {
            return L10n.NotificationsConfigurator.Settings.footer
        } else {
            return L10n.NotificationsConfigurator.Settings.Footer.idSet
        }
    }

    private var yamlPreview: String {
        // Build a throwaway category with the current form values so the YAML
        // reflects unsaved edits, matching the original Eureka behaviour.
        let preview = NotificationCategory()
        preview.Identifier = identifier
        preview.Name = name
        for action in actions {
            preview.Actions.append(action)
        }
        return preview.exampleServiceCall
    }

    // MARK: - Actions mutation

    private func deleteActions(at offsets: IndexSet) {
        let removed = offsets.map { actions[$0] }
        actions.remove(atOffsets: offsets)

        let realm = Current.realm()
        realm.reentrantWrite {
            // Remove from the owning list if already persisted.
            if category.realm != nil {
                let indexes = category.Actions.enumerated().reduce(into: IndexSet()) { set, val in
                    if removed.contains(where: { $0.uuid == val.element.uuid }) {
                        set.insert(val.offset)
                    }
                }
                category.Actions.remove(atOffsets: indexes)
            } else {
                for action in removed {
                    if let index = category.Actions.firstIndex(where: { $0.uuid == action.uuid }) {
                        category.Actions.remove(at: index)
                    }
                }
            }
            let uuids = removed.map(\.uuid)
            realm.delete(realm.objects(NotificationAction.self).filter("uuid IN %@", uuids))
        }
    }

    private func moveActions(from source: IndexSet, to destination: Int) {
        actions.move(fromOffsets: source, toOffset: destination)

        guard category.realm != nil else { return }

        let realm = Current.realm()
        realm.reentrantWrite {
            category.Actions.removeAll()
            for action in actions {
                category.Actions.append(action)
            }
        }
    }

    // MARK: - Editor sheet

    @ViewBuilder
    private func editorSheet(for action: NotificationAction?) -> some View {
        NavigationView {
            NotificationActionEditorView(
                category: category,
                action: action
            ) { savedAction in
                if let saved = savedAction {
                    if let index = actions.firstIndex(where: { $0.uuid == saved.uuid }) {
                        actions[index] = saved
                    } else {
                        actions.append(saved)
                    }
                }
                editingAction = nil
                showingNewAction = false
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Save / validation

    private func validate() -> Bool {
        guard !name.isEmpty else { return false }
        guard NotificationIdentifierField.isValid(identifier, uppercaseOnly: false) else { return false }
        return true
    }

    private func save() {
        let realm = Current.realm()
        let target = existingCategory ?? category

        realm.reentrantWrite {
            target.Name = name
            target.Identifier = identifier
            target.HiddenPreviewsBodyPlaceholder = hiddenPreviewsPlaceholder
            target.CategorySummaryFormat = categorySummaryFormat

            // Replace action list using current order. This must run for both
            // managed and unmanaged categories so the caller can persist the
            // full object graph with `realm.add(_:update:)`.
            target.Actions.removeAll()
            for action in actions {
                target.Actions.append(action)
            }
        }

        onDismiss(target)
        dismiss()
    }

    // MARK: - Toolbar actions

    private func openHelp() {
        guard let url = URL(string: "https://companion.home-assistant.io/app/ios/actionable-notifications") else {
            return
        }
        openURLInBrowser(url, nil)
    }

    private func triggerPreviewNotification() {
        let content = UNMutableNotificationContent()
        content.title = L10n.NotificationsConfigurator.Category.PreviewNotification.title
        content.body = L10n.NotificationsConfigurator.Category.PreviewNotification
            .body(name.isEmpty ? identifier : name)
        content.sound = .default
        content.categoryIdentifier = identifier
        content.userInfo = ["preview": true]

        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        ))
    }
}

// MARK: - NotificationAction Identifiable conformance

extension NotificationAction: Identifiable {
    public var id: String { uuid }
}
