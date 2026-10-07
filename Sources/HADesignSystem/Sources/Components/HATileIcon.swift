#if !os(watchOS)
import HAIconic
import SwiftUI

/// The round, tinted icon a tile leads with. The SwiftUI counterpart of the frontend's
/// `ha-tile-icon`.
///
/// The colour comes from the caller, because what it means — the state of a light, a climate mode —
/// is the app's business, not the design system's.
public struct HATileIcon<Badge: View>: View {
    private let icon: MaterialDesignIcons
    private let color: Color
    private let showsBackground: Bool
    private let badge: Badge

    /// - Parameters:
    ///   - showsBackground: Fills the circle behind the glyph at 20%. The frontend draws it only for
    ///     an interactive icon, so a decorative one is a bare glyph.
    ///   - badge: A small marker pinned to the icon's top trailing corner, e.g. ``HATileBadge``.
    public init(
        icon: MaterialDesignIcons,
        color: Color = .haDisabled,
        showsBackground: Bool = true,
        @ViewBuilder badge: () -> Badge
    ) {
        self.icon = icon
        self.color = color
        self.showsBackground = showsBackground
        self.badge = badge()
    }

    private static var size: CGFloat { 36 }

    public var body: some View {
        MaterialDesignIconsImage(icon: icon, size: 24)
            .foregroundStyle(color)
            .frame(width: Self.size, height: Self.size)
            .background {
                if showsBackground {
                    Circle().fill(color.opacity(0.2))
                }
            }
            .overlay(alignment: .topTrailing) {
                badge
                    // Half outside the circle, so it reads as attached to the icon rather than
                    // crowding the glyph.
                    .offset(x: DesignSystem.Spaces.half, y: -DesignSystem.Spaces.half)
            }
    }
}

public extension HATileIcon where Badge == EmptyView {
    /// An icon with nothing pinned to it.
    init(icon: MaterialDesignIcons, color: Color = .haDisabled, showsBackground: Bool = true) {
        self.init(icon: icon, color: color, showsBackground: showsBackground) { EmptyView() }
    }
}

#Preview {
    HStack(spacing: DesignSystem.Spaces.two) {
        HATileIcon(icon: .lightbulbIcon)
        HATileIcon(icon: .lightbulbOnIcon, color: .haWarningColor)
        HATileIcon(icon: .lightbulbOnIcon, color: .haWarningColor, showsBackground: false)
        HATileIcon(icon: .thermometerIcon, color: .haPrimary) {
            HATileBadge(icon: .alertIcon, color: .haErrorColor)
        }
    }
    .padding()
}

extension HATileIcon: FrontendComponent {
    public static var frontendComponentName: String { "ha-tile-icon" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
