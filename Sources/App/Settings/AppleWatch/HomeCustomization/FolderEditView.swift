import Shared
import SwiftUI

struct FolderEditView: View {
    /// Reference-type holder for the folder being edited. `MagicItem`'s `Equatable` compares
    /// identity only (id/server/type), so storing the folder directly in `@State` makes SwiftUI
    /// consider content-only edits (icon, colors, name) as "no change" and skip re-rendering.
    private final class Draft: ObservableObject {
        @Published var folder: MagicItem

        init(folder: MagicItem) {
            self.folder = folder
        }
    }

    @Environment(\.dismiss) private var dismiss

    @StateObject private var draft: Draft
    @State private var useCustomColors: Bool

    /// The Watch configuration screens force a dark appearance; CarPlay's don't.
    private let usesDarkColorScheme: Bool

    let onSave: (MagicItem) -> Void

    init(folder: MagicItem, usesDarkColorScheme: Bool = true, onSave: @escaping (MagicItem) -> Void) {
        self._draft = StateObject(wrappedValue: Draft(folder: folder))
        self._useCustomColors = State(
            initialValue: folder.customization?.backgroundColor != nil || folder.customization?.textColor != nil
        )
        self.usesDarkColorScheme = usesDarkColorScheme
        self.onSave = onSave
    }

    var body: some View {
        List {
            mainInformationSection
            customizationSection
        }
        .onChange(of: useCustomColors) { newValue in
            if newValue {
                draft.folder.customization?.backgroundColor = draft.folder.customization?.backgroundColor ?? UIColor
                    .black
                    .hexString()
                draft.folder.customization?.textColor = draft.folder.customization?.textColor ?? UIColor.white
                    .hexString()
            } else {
                draft.folder.customization?.backgroundColor = nil
                draft.folder.customization?.textColor = nil
            }
        }
        .navigationTitle(L10n.MagicItem.edit)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onSave(draft.folder)
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
        .preferredColorScheme(usesDarkColorScheme ? .dark : nil)
        .onAppear {
            preventNilCustomization()
        }
    }

    private func preventNilCustomization() {
        if draft.folder.customization == nil {
            draft.folder.customization = .init()
        }
    }

    private var folderName: String {
        draft.folder.displayText ?? draft.folder.id
    }

    private var folderIcon: MaterialDesignIcons {
        if let iconName = draft.folder.customization?.icon {
            return MaterialDesignIcons(named: iconName, fallback: .folderIcon)
        }
        return .folderIcon
    }

    private var iconColor: Color {
        if let iconColorHex = draft.folder.customization?.iconColor {
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
                        draft.folder.customization?.icon = newIcon?.name
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
                        draft.folder.displayText = nil
                    } else {
                        draft.folder.displayText = newValue
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
                if let configIconColor = draft.folder.customization?.iconColor {
                    color = Color(hex: configIconColor)
                } else {
                    draft.folder.customization?.iconColor = color.hex()
                }
                return color
            }, set: { newColor in
                draft.folder.customization?.iconColor = newColor.hex()
            }), supportsOpacity: false)
            Toggle(L10n.MagicItem.UseCustomColors.title, isOn: $useCustomColors)
            if useCustomColors {
                ColorPicker(L10n.MagicItem.BackgroundColor.title, selection: .init(get: {
                    Color(hex: draft.folder.customization?.backgroundColor)
                }, set: { newColor in
                    draft.folder.customization?.backgroundColor = newColor.hex()
                }), supportsOpacity: false)
                ColorPicker(L10n.MagicItem.TextColor.title, selection: .init(get: {
                    Color(hex: draft.folder.customization?.textColor)
                }, set: { newColor in
                    draft.folder.customization?.textColor = newColor.hex()
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
