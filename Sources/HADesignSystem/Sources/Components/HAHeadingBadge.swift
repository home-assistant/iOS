#if !os(watchOS)
import HAIconic
import SwiftUI

/// A small reading set beside a heading — the temperature next to a room's name. The SwiftUI
/// counterpart of the frontend's `ha-heading-badge`.
///
/// Quieter than ``HABadge``: no surface, no border, just an icon and a value in the secondary
/// colour, because it sits on a heading rather than on a dashboard.
public struct HAHeadingBadge: View {
    private let text: String
    private let icon: MaterialDesignIcons?
    private let color: Color
    private let action: (() -> Void)?

    /// - Parameter action: Makes it a button, the frontend's `type="button"`.
    public init(
        _ text: String,
        icon: MaterialDesignIcons? = nil,
        color: Color = .secondary,
        action: (() -> Void)? = nil
    ) {
        self.text = text
        self.icon = icon
        self.color = color
        self.action = action
    }

    public var body: some View {
        let content = HStack(spacing: DesignSystem.Spaces.half) {
            if let icon {
                MaterialDesignIconsImage(icon: icon, size: 14)
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HAHeadingBadge("21.5 °C", icon: .thermometerIcon)
        HAHeadingBadge("64 %", icon: .waterPercentIcon, color: .haPrimary)
        HAHeadingBadge("3 lights on")
        HAHeadingBadge("Tap me", icon: .homeOutlineIcon, action: {})
    }
    .padding()
}

extension HAHeadingBadge: FrontendComponent {
    public static var frontendComponentName: String { "ha-heading-badge" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
