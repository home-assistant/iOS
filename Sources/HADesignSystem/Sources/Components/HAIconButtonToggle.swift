#if !os(watchOS)
import HAIconic
import SwiftUI

/// An icon button that stays pressed, filling a circle behind its glyph while it is on. The SwiftUI
/// counterpart of the frontend's `ha-icon-button-toggle`.
public struct HAIconButtonToggle: View {
    private let icon: MaterialDesignIcons
    private let label: String
    private let borderOnly: Bool
    @Binding private var isSelected: Bool

    /// - Parameters:
    ///   - label: The accessibility name. The frontend uses the same string as the button's title.
    ///   - borderOnly: Rings the glyph instead of filling behind it, the frontend's `border-only`,
    ///     for a toggle sitting on a busy surface where a solid circle would be too loud.
    public init(
        icon: MaterialDesignIcons,
        label: String,
        isSelected: Binding<Bool>,
        borderOnly: Bool = false
    ) {
        self.icon = icon
        self.label = label
        _isSelected = isSelected
        self.borderOnly = borderOnly
    }

    public var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            MaterialDesignIconsImage(icon: icon, size: 24)
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background {
                    if isSelected {
                        Circle()
                            .modify { circle in
                                if borderOnly {
                                    circle.stroke(Color(uiColor: .label), lineWidth: 2)
                                } else {
                                    circle.fill(Color(uiColor: .label))
                                }
                            }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Selected fills the circle with the text colour, so the glyph has to flip to the background
    /// colour to stay readable — the frontend's `--primary-background-color`.
    private var foreground: Color {
        isSelected && !borderOnly ? Color(uiColor: .systemBackground) : Color(uiColor: .label)
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spaces.three) {
        HAIconButtonToggle(icon: .starOutlineIcon, label: "Favourite", isSelected: .constant(false))
        HAIconButtonToggle(icon: .starIcon, label: "Favourite", isSelected: .constant(true))
        HAIconButtonToggle(icon: .starIcon, label: "Favourite", isSelected: .constant(true), borderOnly: true)
    }
    .padding()
}

extension HAIconButtonToggle: FrontendComponent {
    public static var frontendComponentName: String { "ha-icon-button-toggle" }
}

#endif
