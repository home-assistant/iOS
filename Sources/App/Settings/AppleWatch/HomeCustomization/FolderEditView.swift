import Shared
import SwiftUI

struct FolderEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var folder: MagicItem
    @State private var useCustomColors: Bool

    let onSave: (MagicItem) -> Void

    init(folder: MagicItem, onSave: @escaping (MagicItem) -> Void) {
        self._folder = State(initialValue: folder)
        self._useCustomColors = State(
            initialValue: folder.customization?.backgroundColor != nil || folder.customization?.textColor != nil
        )
        self.onSave = onSave
    }

    var body: some View {
        List {
            mainInformationSection
            customizationSection
        }
        .onChange(of: useCustomColors) { newValue in
            if newValue {
                folder.customization?.backgroundColor = folder.customization?.backgroundColor ?? UIColor.black
                    .hexString()
                folder.customization?.textColor = folder.customization?.textColor ?? UIColor.white.hexString()
            } else {
                folder.customization?.backgroundColor = nil
                folder.customization?.textColor = nil
            }
        }
        .navigationTitle(L10n.MagicItem.edit)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onSave(folder)
                    dismiss()
                } label: {
                    Text(L10n.saveLabel)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text(L10n.cancelLabel)
                }
            }
        }
        .onAppear {
            preventNilCustomization()
        }
    }

    private func preventNilCustomization() {
        if folder.customization == nil {
            folder.customization = .init()
        }
    }

    private var folderName: String {
        folder.displayText ?? folder.id
    }

    private var folderIcon: MaterialDesignIcons {
        if let iconName = folder.customization?.icon {
            return MaterialDesignIcons(named: iconName, fallback: .folderIcon)
        }
        return .folderIcon
    }

    private var iconColor: Color {
        if let iconColorHex = folder.customization?.iconColor {
            return Color(hex: iconColorHex)
        }
        return Color.haPrimary
    }

    private var mainInformationSection: some View {
        Section {
            HStack(spacing: DesignSystem.Spaces.two) {
                IconPicker(
                    selectedIcon: .init(get: {
                        folderIcon
                    }, set: { newIcon in
                        folder.customization?.icon = newIcon?.name
                    }),
                    selectedColor: .init(get: {
                        iconColor
                    }, set: { _ in
                        /* no-op */
                    })
                )
                TextField(folderName, text: .init(get: {
                    folderName
                }, set: { newValue in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        folder.displayText = nil
                    } else {
                        folder.displayText = newValue
                    }
                }))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text(verbatim: L10n.MagicItem.DisplayText.title)
        }
    }

    private var customizationSection: some View {
        Section {
            ColorPicker(L10n.MagicItem.IconColor.title, selection: .init(get: {
                var color = Color.haPrimary
                if let configIconColor = folder.customization?.iconColor {
                    color = Color(hex: configIconColor)
                } else {
                    folder.customization?.iconColor = color.hex()
                }
                return color
            }, set: { newColor in
                folder.customization?.iconColor = newColor.hex()
            }), supportsOpacity: false)
            Toggle(L10n.MagicItem.UseCustomColors.title, isOn: $useCustomColors)
            if useCustomColors {
                ColorPicker(L10n.MagicItem.BackgroundColor.title, selection: .init(get: {
                    Color(hex: folder.customization?.backgroundColor)
                }, set: { newColor in
                    folder.customization?.backgroundColor = newColor.hex()
                }), supportsOpacity: false)
                ColorPicker(L10n.MagicItem.TextColor.title, selection: .init(get: {
                    Color(hex: folder.customization?.textColor)
                }, set: { newColor in
                    folder.customization?.textColor = newColor.hex()
                }), supportsOpacity: false)
            }
        }
    }
}

#Preview {
    NavigationView {
        FolderEditView(
            folder: MagicItem(
                id: "folder1",
                serverId: "",
                type: .folder,
                customization: .init(),
                action: .default,
                displayText: "My Folder",
                items: []
            )
        ) { _ in }
    }
}
