#if !os(watchOS)
import HAIconic
import SwiftUI

/// The small marker pinned to a tile's icon — a battery warning, an unavailable mark. The SwiftUI
/// counterpart of the frontend's `ha-tile-badge`.
public struct HATileBadge: View {
    private let icon: MaterialDesignIcons
    private let color: Color

    public init(icon: MaterialDesignIcons, color: Color = .haPrimary) {
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        MaterialDesignIconsImage(icon: icon, size: 12)
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spaces.two) {
        HATileBadge(icon: .alertIcon)
        HATileBadge(icon: .alertIcon, color: .haErrorColor)
        HATileBadge(icon: .batteryLowIcon, color: .haWarningColor)
    }
    .padding()
}

extension HATileBadge: FrontendComponent {
    public static var frontendComponentName: String { "ha-tile-badge" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
