import SFSafeSymbols
import Shared
import SwiftUI

/// A watch-sized icon picker row. The iPhone `IconPicker` lives in the app target, so this is a
/// minimal port over `MaterialDesignIcons.allCases`. It binds to the stored icon name (the value kept
/// in `MagicItem.Customization.icon`); `nil` means "use the default icon for the item". It pushes a
/// searchable 3-column grid onto the surrounding navigation stack.
struct WatchIconPicker: View {
    @Binding var iconName: String?
    /// Shown when no custom icon is chosen — the item's own resolved icon, so the row matches the
    /// entity's appearance instead of a generic placeholder.
    var defaultIcon: MaterialDesignIcons = .dotsGridIcon

    private var selectedIcon: MaterialDesignIcons {
        if let iconName {
            return MaterialDesignIcons(named: iconName, fallback: defaultIcon)
        }
        return defaultIcon
    }

    var body: some View {
        NavigationLink {
            WatchIconPickerGrid(iconName: $iconName)
        } label: {
            HStack(spacing: DesignSystem.Spaces.one) {
                Image(uiImage: selectedIcon.image(
                    ofSize: .init(width: 24, height: 24),
                    color: UIColor(Color.haPrimary)
                ))
                Text(verbatim: L10n.Watch.Config.Edit.icon)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct WatchIconPickerGrid: View {
    @Binding var iconName: String?
    @Environment(\.dismiss) private var dismiss
    @State private var searchTerm = ""

    private static let allIcons = MaterialDesignIcons.allCases.sorted { $0.name < $1.name }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spaces.one), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.one) {
                TextField(L10n.Watch.Config.Edit.IconSearch.placeholder, text: $searchTerm)

                if iconName != nil {
                    Button(role: .destructive) {
                        iconName = nil
                        dismiss()
                    } label: {
                        Label(L10n.Watch.Config.Edit.IconSearch.useDefault, systemSymbol: .arrowUturnBackward)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: columns, spacing: DesignSystem.Spaces.one) {
                    ForEach(filteredIcons, id: \.self) { icon in
                        Button {
                            iconName = icon.name
                            dismiss()
                        } label: {
                            iconCell(icon)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.half)
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Config.Edit.icon))
    }

    private func iconCell(_ icon: MaterialDesignIcons) -> some View {
        let isSelected = icon.name == iconName
        return Image(uiImage: icon.image(
            ofSize: .init(width: 28, height: 28),
            color: UIColor(Color.haPrimary)
        ))
        .frame(width: 44, height: 44)
        .background(
            (isSelected ? Color.haPrimary.opacity(0.4) : Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
        )
    }

    private var filteredIcons: [MaterialDesignIcons] {
        let term = searchTerm.trimmingCharacters(in: .whitespaces).lowercased()
        guard !term.isEmpty else { return Self.allIcons }
        return Self.allIcons.filter { $0.name.lowercased().contains(term) }
    }
}
