#if !os(watchOS)
import HAIconic
import SwiftUI

/// A chip offering an action alongside the content it relates to. The SwiftUI counterpart of the
/// frontend's `ha-assist-chip`.
///
/// Outlined by default; `filled` swaps the outline for a solid fill, which the frontend adds on top
/// of Material because Material 3 has no filled assist chip.
public struct HAAssistChip: View {
    private let label: String
    private let icon: MaterialDesignIcons?
    private let trailingIcon: MaterialDesignIcons?
    private let filled: Bool
    private let isActive: Bool
    private let action: () -> Void

    /// - Parameters:
    ///   - filled: Draws a solid fill instead of the outline.
    ///   - isActive: Marks the chip as currently in effect, tinting its fill.
    public init(
        _ label: String,
        icon: MaterialDesignIcons? = nil,
        trailingIcon: MaterialDesignIcons? = nil,
        filled: Bool = false,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.trailingIcon = trailingIcon
        self.filled = filled
        self.isActive = isActive
        self.action = action
    }

    private var background: Color {
        if isActive {
            .haPrimary.opacity(0.15)
        } else if filled {
            Color(uiColor: .label).opacity(0.08)
        } else {
            .clear
        }
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spaces.one) {
                if let icon {
                    MaterialDesignIconsImage(icon: icon, size: 18)
                }
                Text(label)
                if let trailingIcon {
                    MaterialDesignIconsImage(icon: trailingIcon, size: 18)
                }
            }
            .haChipShape(
                cornerRadius: DesignSystem.CornerRadius.two,
                background: background,
                // A filled chip carries no outline: the frontend replaces the outline with the fill
                // rather than drawing both.
                showsOutline: !filled
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HAAssistChip("Outlined") {}
        HAAssistChip("With icon", icon: .homeOutlineIcon) {}
        HAAssistChip("Trailing icon", trailingIcon: .chevronDownIcon) {}
        HAAssistChip("Filled", filled: true) {}
        HAAssistChip("Active", icon: .homeOutlineIcon, isActive: true) {}
    }
    .padding()
}

extension HAAssistChip: FrontendComponent {
    public static var frontendComponentName: String { "ha-assist-chip" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
