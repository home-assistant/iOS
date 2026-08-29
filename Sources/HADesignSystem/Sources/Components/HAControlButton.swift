#if !os(watchOS)
import HAIconic
import SwiftUI

/// A square, quietly-filled icon button sized to sit beside a slider or a switch in a tile. The
/// SwiftUI counterpart of the frontend's `ha-control-button`.
public struct HAControlButton: View {
    private let icon: MaterialDesignIcons
    private let label: String
    private let isDisabled: Bool
    private let action: () -> Void

    /// - Parameter label: The accessibility name. The frontend puts the same string in `title`,
    ///   since the button shows only its glyph.
    public init(
        icon: MaterialDesignIcons,
        label: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            MaterialDesignIconsImage(icon: icon, size: 20)
                .foregroundStyle(isDisabled ? Color.secondary : Color(uiColor: .label))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.haDisabled.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 40)
        .disabled(isDisabled)
        .accessibilityLabel(Text(label))
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
        HAControlButton(icon: .powerIcon, label: "Toggle") {}
        HAControlButton(icon: .plusIcon, label: "Increase") {}
        HAControlButton(icon: .minusIcon, label: "Decrease", isDisabled: true) {}
    }
    .padding()
}

extension HAControlButton: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-button" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
