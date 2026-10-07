#if !os(watchOS)
import HAIconic
import SwiftUI

/// A section heading that sits in the card grid, optionally with badges alongside. The SwiftUI
/// counterpart of the frontend's `hui-heading-card`.
///
/// Draws no card surface of its own — a heading separates the cards under it rather than being one,
/// which is why this is the one "card" without an ``HACard``.
public struct HAHeadingCard<Badges: View>: View {
    /// The two weights the frontend offers, its `heading_style`.
    public enum Style: String, CaseIterable, Sendable {
        case title
        case subtitle
    }

    private let heading: String
    private let icon: MaterialDesignIcons?
    private let style: Style
    private let onTap: (() -> Void)?
    private let badges: Badges

    public init(
        heading: String,
        icon: MaterialDesignIcons? = nil,
        style: Style = .title,
        onTap: (() -> Void)? = nil,
        @ViewBuilder badges: () -> Badges
    ) {
        self.heading = heading
        self.icon = icon
        self.style = style
        self.onTap = onTap
        self.badges = badges()
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            if let icon {
                MaterialDesignIconsImage(icon: icon, size: style == .title ? 20 : 16)
                    .foregroundStyle(.secondary)
            }
            Text(heading)
                .font(style == .title ? DesignSystem.Font.title3 : DesignSystem.Font.subheadline)
                .foregroundStyle(style == .title ? Color(uiColor: .label) : .secondary)
            Spacer(minLength: DesignSystem.Spaces.one)
            badges
        }
        .padding(.vertical, DesignSystem.Spaces.one)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityAddTraits(onTap == nil ? .isHeader : [.isHeader, .isButton])
    }
}

public extension HAHeadingCard where Badges == EmptyView {
    /// A heading with nothing beside it.
    init(
        heading: String,
        icon: MaterialDesignIcons? = nil,
        style: Style = .title,
        onTap: (() -> Void)? = nil
    ) {
        self.init(heading: heading, icon: icon, style: style, onTap: onTap) { EmptyView() }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HAHeadingCard(heading: "Living room", icon: .sofaIcon)
        HAHeadingCard(heading: "Upstairs", style: .subtitle)
        HAHeadingCard(heading: "Kitchen", icon: .silverwareForkKnifeIcon) {
            HABadge("21.5 °C", icon: .thermometerIcon)
        }
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAHeadingCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-heading-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
