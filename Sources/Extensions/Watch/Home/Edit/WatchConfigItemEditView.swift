import SFSafeSymbols
import Shared
import SwiftUI

/// Name + icon (+ confirmation) editor for a watch item or folder, used both when adding and when
/// editing. It starts from the existing `MagicItem` and mutates only `displayText`,
/// `customization.icon`, `iconIsCustomized` and `requiresConfirmation`, so colors and the action are
/// preserved — matching the iPhone `WatchConfigurationViewModel.updateItem`.
///
/// It does NOT own a `NavigationView`: in the add flow it's pushed onto the flow's navigation stack;
/// in edit mode the caller wraps it in a `NavigationView` inside a sheet. The caller's `onCommit`
/// performs the mutation and handles dismissal.
struct WatchConfigItemEditView: View {
    enum Mode {
        case add
        case edit
    }

    let mode: Mode
    /// Placeholder shown in the name field — the entity's own name, so leaving it blank keeps the
    /// entity name.
    let placeholderName: String
    let info: MagicItem.Info?
    let onCommit: (MagicItem) -> Void
    /// Provided only in edit mode: shows a destructive Delete action that removes the item.
    let onDelete: (() -> Void)?

    private let originalItem: MagicItem

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var iconName: String?
    @State private var requiresConfirmation: Bool

    init(
        mode: Mode,
        placeholderName: String,
        item: MagicItem,
        info: MagicItem.Info?,
        onCommit: @escaping (MagicItem) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.placeholderName = placeholderName
        self.originalItem = item
        self.info = info
        self.onCommit = onCommit
        self.onDelete = onDelete
        _name = State(initialValue: item.displayText ?? "")
        _iconName = State(initialValue: item.customization?.icon)
        // Same default as iOS: `Customization.requiresConfirmation` defaults to false.
        _requiresConfirmation = State(initialValue: item.customization?.requiresConfirmation ?? false)
    }

    private var isFolder: Bool { originalItem.type == .folder }

    var body: some View {
        List {
            Section {
                TextField(placeholderName, text: $name)
                WatchIconPicker(iconName: $iconName, defaultIcon: defaultIcon)
            }
            if !isFolder {
                Section {
                    Toggle(isOn: $requiresConfirmation) {
                        Text(verbatim: L10n.Watch.Config.Edit.requireConfirmation)
                    }
                }
            }
            Section {
                WatchConfigItemRow(item: previewItem, itemInfo: previewInfo)
                    // `MagicItem`'s `==` is identity-only (ignores displayText/customization), so force
                    // the preview to rebuild when the pending name/icon changes.
                    .id("\(trimmedName)|\(iconName ?? "")")
                    .watchConfigRowBackground()
            } header: {
                Text(verbatim: L10n.Watch.Config.Edit.preview)
            }
            if mode == .edit, let onDelete {
                Section {
                    Button(role: .destructive, action: onDelete) {
                        Label(L10n.Watch.Config.Edit.delete, systemSymbol: .trash)
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: title))
        // A conditional inside `.toolbar { }` needs `ToolbarContentBuilder.buildIf`, which is
        // watchOS 9+. Pick the toolbar variant outside the builder instead (each is static).
        .modify { view in
            if mode == .edit {
                view.toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.cancelLabel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        confirmButton
                    }
                }
            } else {
                view.toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        confirmButton
                    }
                }
            }
        }
    }

    private var confirmButton: some View {
        Button(commitLabel) { onCommit(editedItem) }
            .disabled(isFolder && trimmedName.isEmpty)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editedItem: MagicItem {
        var item = originalItem
        item.displayText = trimmedName.isEmpty ? nil : trimmedName
        var customization = item.customization ?? .init()
        customization.icon = iconName
        customization.iconIsCustomized = iconName != nil
        customization.requiresConfirmation = requiresConfirmation
        item.customization = customization
        return item
    }

    private var previewItem: MagicItem { editedItem }

    private var previewInfo: MagicItem.Info {
        info ?? .init(
            id: originalItem.serverUniqueId,
            name: originalItem.displayText ?? originalItem.id,
            iconName: ""
        )
    }

    /// The item's own resolved icon, ignoring any pending custom-icon choice — used as the icon
    /// picker's placeholder so it shows the entity's icon.
    private var defaultIcon: MaterialDesignIcons {
        var item = originalItem
        var customization = item.customization ?? .init()
        customization.icon = nil
        item.customization = customization
        return item.icon(info: previewInfo)
    }

    private var title: String {
        switch (isFolder, mode) {
        case (true, .add): return L10n.Watch.Config.Edit.Folder.addTitle
        case (true, .edit): return L10n.Watch.Config.Edit.Folder.editTitle
        case (false, .add): return L10n.Watch.Config.Edit.Item.addTitle
        case (false, .edit): return L10n.Watch.Config.Edit.Item.editTitle
        }
    }

    private var commitLabel: String {
        mode == .add ? L10n.Watch.Config.Edit.addButton : L10n.Watch.Config.Edit.saveButton
    }
}
