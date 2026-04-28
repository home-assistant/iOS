import Shared
import SwiftUI

/// A SwiftUI searchable picker for `MaterialDesignIcons`. Replaces the
/// `SearchPushRow<MaterialDesignIcons>` usage in the complication editor.
struct IconSearchPicker: View {
    @Binding var selectedIcon: MaterialDesignIcons
    let tintColor: Color
    let title: String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: DesignSystem.Spaces.one) {
                    // The UIImage is rendered with the desired tint color baked in;
                    // keep the original rendering mode so SwiftUI doesn't strip it.
                    Image(uiImage: selectedIcon.image(
                        ofSize: CGSize(width: 24, height: 24),
                        color: UIColor(tintColor)
                    ))
                    Text(selectedIcon.name)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            IconSearchSheet(
                selectedIcon: $selectedIcon,
                tintColor: tintColor,
                isPresented: $isPresented
            )
        }
    }
}

private struct IconSearchSheet: View {
    @Binding var selectedIcon: MaterialDesignIcons
    let tintColor: Color
    @Binding var isPresented: Bool

    @State private var searchTerm: String = ""

    private static let allIcons: [MaterialDesignIcons] = MaterialDesignIcons.allCases
        .sorted(by: { $0.name < $1.name })

    private var filteredIcons: [MaterialDesignIcons] {
        let query = searchTerm.lowercased()
        guard query.count >= 2 else { return Self.allIcons }
        return Self.allIcons.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationView {
            List(filteredIcons, id: \.self) { icon in
                Button {
                    selectedIcon = icon
                    isPresented = false
                } label: {
                    HStack(spacing: DesignSystem.Spaces.two) {
                        // Keep the baked-in tint color rather than letting SwiftUI flatten
                        // the template image to a single color (was discarding `tintColor`).
                        Image(uiImage: icon.image(
                            ofSize: CGSize(width: 30, height: 30),
                            color: UIColor(tintColor)
                        ))
                        Text(icon.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if icon == selectedIcon {
                            Image(systemSymbol: .checkmark)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .searchable(text: $searchTerm)
            .navigationTitle(L10n.Watch.Configurator.Rows.Icon.Choose.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancelLabel) { isPresented = false }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
