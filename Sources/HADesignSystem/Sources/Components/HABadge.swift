#if !os(watchOS)
import HAIconic
import SwiftUI

/// A pill sitting above a dashboard view: an icon, an optional small label and a value. The SwiftUI
/// counterpart of the frontend's `ha-badge`.
///
/// `color` tints the icon only — the pill itself always uses the card surface, which is what keeps a
/// row of badges reading as one strip however differently their contents are tinted.
public struct HABadge<Content: View>: View {
    private let icon: MaterialDesignIcons?
    private let label: String?
    private let color: Color
    private let iconOnly: Bool
    private let action: (() -> Void)?
    private let content: Content

    /// - Parameters:
    ///   - label: The small caption above the content. `ha-badge` omits the row when it is absent.
    ///   - color: Tints the icon. Defaults to secondary, the frontend's `--badge-color`.
    ///   - iconOnly: Drops the text and squares the pill down to its icon, for a compact row.
    ///   - action: Makes the badge a button — `ha-badge`'s `type="button"`.
    public init(
        icon: MaterialDesignIcons? = nil,
        label: String? = nil,
        color: Color = .secondary,
        iconOnly: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.label = label
        self.color = color
        self.iconOnly = iconOnly
        self.action = action
        self.content = content()
    }

    /// 36pt tall with a radius of half that, so the ends are semicircular whatever the width.
    private static var height: CGFloat { 36 }

    public var body: some View {
        let badge = HStack(spacing: DesignSystem.Spaces.one) {
            if let icon {
                MaterialDesignIconsImage(icon: icon, size: 18)
                    .foregroundStyle(color)
            }
            if !iconOnly {
                VStack(alignment: .leading, spacing: .zero) {
                    if let label {
                        Text(label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    content
                        .font(.system(size: 12, weight: .medium))
                }
            }
        }
        .padding(.horizontal, iconOnly ? .zero : DesignSystem.Spaces.oneAndHalf)
        .frame(minWidth: Self.height, minHeight: Self.height)
        .background(Color.haCardBackground)
        .overlay(Capsule().strokeBorder(Color.haDivider, lineWidth: DesignSystem.Border.Width.default))
        // Clipped after the border, not before: an inset stroke still antialiases a hairline past
        // the capsule's widest points, which shows as nicks against the surface behind it.
        .clipShape(Capsule())

        if let action {
            Button(action: action) { badge }
                .buttonStyle(.plain)
        } else {
            badge
        }
    }
}

public extension HABadge where Content == Text {
    /// A badge whose content is plain text — the common case.
    init(
        _ text: String,
        icon: MaterialDesignIcons? = nil,
        label: String? = nil,
        color: Color = .secondary,
        action: (() -> Void)? = nil
    ) {
        self.init(icon: icon, label: label, color: color, iconOnly: false, action: action) {
            Text(text)
        }
    }

    /// A badge showing nothing but its icon.
    init(icon: MaterialDesignIcons, color: Color = .secondary, action: (() -> Void)? = nil) {
        self.init(icon: icon, label: nil, color: color, iconOnly: true, action: action) {
            Text("")
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HABadge("21.5 °C", icon: .thermometerIcon)
        HABadge("21.5 °C", icon: .thermometerIcon, label: "Living room")
        HABadge("On", icon: .lightbulbOnIcon, color: .haWarningColor)
        HABadge(icon: .homeOutlineIcon)
        HABadge("Tap me", icon: .homeOutlineIcon, action: {})
        HABadge("No icon")
    }
    .padding()
}

extension HABadge: FrontendComponent {
    public static var frontendComponentName: String { "ha-badge" }
}

#endif
