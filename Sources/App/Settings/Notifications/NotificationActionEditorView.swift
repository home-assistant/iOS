import RealmSwift
import Shared
import SwiftUI

/// SwiftUI replacement for `NotificationActionConfigurator`.
///
/// Edits a `NotificationAction` belonging to an owning `NotificationCategory`.
/// Changes are kept in local view state until the user taps Save, at which
/// point they are written back into the Realm-managed action (if managed) and
/// appended to the owning category if new. Matches the original Eureka
/// behaviour, including conditional text-input rows, YAML trigger preview and
/// read-only mode for server-controlled actions.
struct NotificationActionEditorView: View {
    let category: NotificationCategory
    let existingAction: NotificationAction?

    /// Called with the persisted action when the user finishes editing.
    /// `nil` is passed if the user cancelled without saving.
    let onDismiss: (NotificationAction?) -> Void

    @Environment(\.dismiss) private var dismiss

    // Local editable state mirrored from the action being edited.
    @State private var title: String
    @State private var identifier: String
    @State private var textInput: Bool
    @State private var textInputButtonTitle: String
    @State private var textInputPlaceholder: String
    @State private var foreground: Bool
    @State private var destructive: Bool
    @State private var authenticationRequired: Bool

    @State private var showValidationAlert = false

    private let isNewAction: Bool
    private let isServerControlled: Bool

    init(
        category: NotificationCategory,
        action: NotificationAction?,
        onDismiss: @escaping (NotificationAction?) -> Void
    ) {
        self.category = category
        self.existingAction = action
        self.onDismiss = onDismiss

        let resolved = action ?? NotificationAction()
        self.isNewAction = (action == nil)
        self.isServerControlled = resolved.isServerControlled

        _title = State(initialValue: resolved.Title)
        _identifier = State(initialValue: resolved.Identifier)
        _textInput = State(initialValue: resolved.TextInput)
        _textInputButtonTitle = State(initialValue: resolved.TextInputButtonTitle)
        _textInputPlaceholder = State(initialValue: resolved.TextInputPlaceholder)
        _foreground = State(initialValue: resolved.Foreground)
        _destructive = State(initialValue: resolved.Destructive)
        _authenticationRequired = State(initialValue: resolved.AuthenticationRequired)
    }

    var body: some View {
        Form {
            settingsSection

            if !isServerControlled {
                textInputSection
                foregroundSection
                destructiveSection
                authenticationSection
            }

            YamlPreviewSection(
                header: L10n.ActionsConfigurator.TriggerExample.title,
                yaml: yamlPreview
            )
        }
        .navigationTitle(isNewAction ? L10n.NotificationsConfigurator.NewAction.title : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
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
                Text(L10n.NotificationsConfigurator.Action.Rows.Title.title)
                Spacer()
                TextField("", text: $title)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(title.isEmpty ? .red : .primary)
                    .disabled(isServerControlled)
            }

            NotificationIdentifierTextField(
                title: L10n.NotificationsConfigurator.identifier,
                text: $identifier,
                uppercaseOnly: true,
                isDisabled: isServerControlled || !isNewAction
            )
        }
    }

    private var textInputSection: some View {
        Section {
            Toggle(
                L10n.NotificationsConfigurator.Action.TextInput.title,
                isOn: $textInput
            )

            if textInput {
                HStack {
                    Text(L10n.NotificationsConfigurator.Action.Rows.TextInputButtonTitle.title)
                    Spacer()
                    TextField("", text: $textInputButtonTitle)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text(L10n.NotificationsConfigurator.Action.Rows.TextInputPlaceholder.title)
                    Spacer()
                    TextField("", text: $textInputPlaceholder)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var foregroundSection: some View {
        Section(footer: Text(L10n.NotificationsConfigurator.Action.Rows.Foreground.footer)) {
            Toggle(
                L10n.NotificationsConfigurator.Action.Rows.Foreground.title,
                isOn: $foreground
            )
        }
    }

    private var destructiveSection: some View {
        Section(footer: Text(L10n.NotificationsConfigurator.Action.Rows.Destructive.footer)) {
            Toggle(
                L10n.NotificationsConfigurator.Action.Rows.Destructive.title,
                isOn: $destructive
            )
        }
    }

    private var authenticationSection: some View {
        Section(footer: Text(L10n.NotificationsConfigurator.Action.Rows.AuthenticationRequired.footer)) {
            Toggle(
                L10n.NotificationsConfigurator.Action.Rows.AuthenticationRequired.title,
                isOn: $authenticationRequired
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // `if` directly inside a `@ToolbarContentBuilder` requires the iOS 16+
        // ToolbarContentBuilder. Always emit the items and gate their content
        // (a regular ViewBuilder context) so this compiles on iOS 15.
        ToolbarItem(placement: .cancellationAction) {
            if !isServerControlled {
                Button(L10n.cancelLabel) {
                    onDismiss(nil)
                    dismiss()
                }
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            if !isServerControlled {
                Button(L10n.saveLabel) {
                    if validate() {
                        save()
                    } else {
                        showValidationAlert = true
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private var settingsFooter: String {
        if isServerControlled {
            return ""
        } else if isNewAction {
            return L10n.NotificationsConfigurator.Settings.footer
        } else {
            return L10n.NotificationsConfigurator.Settings.Footer.idSet
        }
    }

    private var yamlPreview: String {
        guard let api = Current.apis.first else { return "" }
        return NotificationAction.exampleTrigger(
            api: api,
            identifier: identifier,
            category: category.Identifier,
            textInput: textInput
        )
    }

    private func validate() -> Bool {
        guard !title.isEmpty else { return false }
        guard NotificationIdentifierField.isValid(identifier, uppercaseOnly: true) else { return false }
        if textInput {
            guard !textInputButtonTitle.isEmpty, !textInputPlaceholder.isEmpty else { return false }
        }
        return true
    }

    private func save() {
        let realm = Current.realm()
        let action = existingAction ?? NotificationAction()

        realm.reentrantWrite {
            if isNewAction {
                action.Identifier = identifier
            }
            action.Title = title
            action.TextInput = textInput
            action.TextInputButtonTitle = textInputButtonTitle
            action.TextInputPlaceholder = textInputPlaceholder
            action.Foreground = foreground
            action.Destructive = destructive
            action.AuthenticationRequired = authenticationRequired

            // Only add into Realm if the category is already persisted.
            category.realm?.add(action, update: .all)
            if category.Actions.contains(action) == false {
                category.Actions.append(action)
            }
        }

        onDismiss(action)
        dismiss()
    }
}
