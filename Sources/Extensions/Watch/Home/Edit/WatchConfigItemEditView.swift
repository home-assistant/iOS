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
    @State private var iconColorHex: String?
    @State private var backgroundColorHex: String?
    @State private var textColorHex: String?
    @State private var useCustomColors: Bool

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
        _iconColorHex = State(initialValue: item.customization?.iconColor)
        _backgroundColorHex = State(initialValue: item.customization?.backgroundColor)
        _textColorHex = State(initialValue: item.customization?.textColor)
        _useCustomColors = State(
            initialValue: item.customization?.backgroundColor != nil || item.customization?.textColor != nil
        )
    }

    private var isFolder: Bool { originalItem.type == .folder }

    var body: some View {
        List {
            Section {
                TextField(placeholderName, text: $name)
                WatchIconPicker(iconName: $iconName, defaultIcon: defaultIcon)
            }
            Section {
                WatchColorPicker(title: L10n.MagicItem.IconColor.title, colorHex: $iconColorHex)
                Toggle(isOn: $useCustomColors) {
                    Text(verbatim: L10n.MagicItem.UseCustomColors.title)
                }
                if useCustomColors {
                    WatchColorPicker(title: L10n.MagicItem.BackgroundColor.title, colorHex: $backgroundColorHex)
                    WatchColorPicker(title: L10n.MagicItem.TextColor.title, colorHex: $textColorHex)
                }
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
                    // the preview to rebuild when the pending name/icon/color changes.
                    .id("\(trimmedName)|\(iconName ?? "")|\(iconColorHex ?? "")")
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
        .onChange(of: useCustomColors) { newValue in
            // Match iOS: seed sensible defaults when turning custom colors on, clear when off.
            if newValue {
                if backgroundColorHex == nil { backgroundColorHex = Color.haPrimary.hex() }
                if textColorHex == nil { textColorHex = Color.white.hex() }
            } else {
                backgroundColorHex = nil
                textColorHex = nil
            }
        }
        // A conditional inside `.toolbar { }` needs `ToolbarContentBuilder.buildIf`, which is
        // watchOS 9+. Pick the toolbar variant outside the builder instead (each is static).
        .modify { view in
            if mode == .edit {
                view.toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        cancelButton
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
        Button {
            onCommit(editedItem)
        } label: {
            Image(systemSymbol: .checkmark)
        }
        .tint(.haPrimary)
        .disabled(isFolder && trimmedName.isEmpty)
    }

    private var cancelButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemSymbol: .xmark)
        }
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
        customization.iconColor = iconColorHex
        if useCustomColors {
            customization.backgroundColor = backgroundColorHex
            customization.textColor = textColorHex
        } else {
            customization.backgroundColor = nil
            customization.textColor = nil
        }
        item.customization = customization
        return item
    }

    private var previewItem: MagicItem { editedItem }

    /// Carries the pending customization so the preview reflects the chosen icon color live.
    private var previewInfo: MagicItem.Info {
        .init(
            id: info?.id ?? originalItem.serverUniqueId,
            name: info?.name ?? (originalItem.displayText ?? originalItem.id),
            iconName: info?.iconName ?? "",
            customization: editedItem.customization,
            contextSubtitle: info?.contextSubtitle
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
}

/// A watch-friendly color picker row. `ColorPicker` isn't available on watchOS, so this shows the
/// current swatch and pushes a palette grid. `nil` means "use the default color".
struct WatchColorPicker: View {
    let title: String
    @Binding var colorHex: String?

    var body: some View {
        NavigationLink {
            WatchColorPickerGrid(title: title, colorHex: $colorHex)
        } label: {
            HStack(spacing: DesignSystem.Spaces.one) {
                swatch(for: colorHex, size: 24)
                Text(verbatim: title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

@ViewBuilder
private func swatch(for hex: String?, size: CGFloat, selected: Bool = false) -> some View {
    if let hex {
        Circle()
            .fill(Color(uiColor: UIColor(hex: hex)))
            .frame(width: size, height: size)
            .overlay {
                if selected {
                    Circle().strokeBorder(Color.white, lineWidth: 3)
                }
            }
    } else {
        // "Default" — no custom color set.
        Circle()
            .strokeBorder(selected ? Color.haPrimary : Color.secondary, lineWidth: 2)
            .frame(width: size, height: size)
    }
}

private struct WatchColorPickerGrid: View {
    let title: String
    @Binding var colorHex: String?
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spaces.one), count: 4)
    private static let palette: [String] = [
        "F44336", "E91E63", "9C27B0", "673AB7",
        "3F51B5", "2196F3", "03A9F4", "00BCD4",
        "009688", "4CAF50", "8BC34A", "CDDC39",
        "FFEB3B", "FFC107", "FF9800", "FF5722",
        "795548", "9E9E9E", "607D8B", "FFFFFF",
        "000000",
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DesignSystem.Spaces.one) {
                Button {
                    colorHex = nil
                    dismiss()
                } label: {
                    swatch(for: nil, size: 40, selected: isSelected(nil))
                }
                .buttonStyle(.plain)
                ForEach(Self.palette, id: \.self) { hex in
                    Button {
                        colorHex = hex
                        dismiss()
                    } label: {
                        swatch(for: hex, size: 40, selected: isSelected(hex))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spaces.one)
        }
        .navigationTitle(Text(verbatim: title))
    }

    private func isSelected(_ hex: String?) -> Bool {
        guard let hex else { return colorHex == nil }
        return colorHex?.caseInsensitiveCompare(hex) == .orderedSame
    }
}
