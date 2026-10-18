#if !os(watchOS)
import HAIconic
import SwiftUI

/// A square, quietly-filled icon button sized to sit beside a slider or a switch in a tile. The
/// SwiftUI counterpart of the frontend's `ha-control-button`.
public struct HAControlButton: View {
    private let icon: MaterialDesignIcons?
    private let title: String?
    private let label: String
    private let isDisabled: Bool
    private let size: CGFloat?
    private let cornerRadius: CGFloat
    private let iconSize: CGFloat
    private let activeColor: Color?
    private let action: () -> Void

    /// - Parameters:
    ///   - label: The accessibility name. The frontend puts the same string in `title`, since the
    ///     button shows only its glyph.
    ///   - size: The side of the square. `nil` fills whatever the parent offers, as the more-info
    ///     cover buttons and toggle fallbacks do.
    ///   - activeColor: Fills the button with this colour and turns the glyph white: the
    ///     frontend's `.active` button, for the state the entity is in now.
    public init(
        icon: MaterialDesignIcons,
        label: String,
        isDisabled: Bool = false,
        size: CGFloat? = 40,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.one,
        iconSize: CGFloat = 20,
        activeColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = nil
        self.label = label
        self.isDisabled = isDisabled
        self.size = size
        self.cornerRadius = cornerRadius
        self.iconSize = iconSize
        self.activeColor = activeColor
        self.action = action
    }

    /// A button that reads as words rather than a glyph, like the lock's "Open door".
    public init(
        title: String,
        isDisabled: Bool = false,
        size: CGFloat? = nil,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.one,
        activeColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = nil
        self.title = title
        self.label = title
        self.isDisabled = isDisabled
        self.size = size
        self.cornerRadius = cornerRadius
        self.iconSize = 20
        self.activeColor = activeColor
        self.action = action
    }

    private var foreground: Color {
        if isDisabled {
            return .secondary
        }
        return activeColor == nil ? Color(uiColor: .label) : .white
    }

    public var body: some View {
        Button(action: action) {
            Group {
                if let icon {
                    MaterialDesignIconsImage(icon: icon, size: iconSize)
                } else if let title {
                    Text(title)
                        .font(DesignSystem.Font.subheadline.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, DesignSystem.Spaces.two)
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(activeColor ?? Color.haDisabled.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .disabled(isDisabled)
        .accessibilityLabel(Text(label))
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
            HAControlButton(icon: .powerIcon, label: "Toggle") {}
            HAControlButton(icon: .plusIcon, label: "Increase") {}
            HAControlButton(icon: .minusIcon, label: "Decrease", isDisabled: true) {}
            HAControlButton(icon: .flashIcon, label: "On", activeColor: .orange) {}
        }
        HAControlButton(title: "Open door") {}
            .frame(height: 40)
    }
    .padding()
}

extension HAControlButton: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-button" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
