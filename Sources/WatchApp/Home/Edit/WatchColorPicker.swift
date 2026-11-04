import Shared
import SwiftUI

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
