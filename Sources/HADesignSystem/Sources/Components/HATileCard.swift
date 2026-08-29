#if !os(watchOS)
import HAIconic
import SwiftUI

/// The dashboard's tile: an icon, a name and a state on a card, optionally with controls under it.
/// The SwiftUI counterpart of the frontend's `hui-tile-card` and its `ha-tile-container`.
///
/// Not to be confused with `WidgetTileView`, which draws the Home Screen widget's tiles at widget
/// sizes from a `WidgetTileModel`. This one is the dashboard card.
///
/// It takes plain values rather than an entity, in the same way the widget components do — mapping a
/// state onto an icon, a colour and two strings is the app's job.
public struct HATileCard<Features: View>: View {
    private let icon: MaterialDesignIcons
    private let color: Color
    private let primary: String
    private let secondary: String?
    private let vertical: Bool
    private let isActive: Bool
    private let onTap: (() -> Void)?
    private let features: Features

    /// - Parameters:
    ///   - isActive: Lets the tile's colour through to the icon. Inactive, the icon falls back to
    ///     the disabled grey and `color` is ignored. The card itself is *not* tinted: checked
    ///     against the rendered `hui-tile-card`, whose `active` class only redirects `--tile-color`
    ///     at `ha-tile-icon`, leaving the card white.
    ///   - features: Controls drawn under the tile's row, e.g. a slider or a mode select.
    public init(
        icon: MaterialDesignIcons,
        color: Color = .haDisabled,
        primary: String,
        secondary: String? = nil,
        vertical: Bool = false,
        isActive: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder features: () -> Features
    ) {
        self.icon = icon
        self.color = color
        self.primary = primary
        self.secondary = secondary
        self.vertical = vertical
        self.isActive = isActive
        self.onTap = onTap
        self.features = features()
    }

    /// `--row-height`, the height a tile's icon-and-text row reserves so a grid of tiles lines up.
    private static var rowHeight: CGFloat { 56 }

    /// `--tile-color`: the entity's colour when it is on, the disabled grey when it is not.
    private var iconColor: Color {
        isActive ? color : .haDisabled
    }

    public var body: some View {
        HACard {
            VStack(spacing: .zero) {
                // Written out per axis rather than swapped with `AnyLayout`: erased behind one, the
                // row reports its ideal height as if it were the horizontal arrangement, and a
                // vertical tile then overflows the 56pt minimum instead of growing past it.
                Group {
                    if vertical {
                        VStack(spacing: DesignSystem.Spaces.one) {
                            HATileIcon(icon: icon, color: iconColor)
                            HATileInfo(primary: primary, secondary: secondary, alignment: .center)
                        }
                    } else {
                        HStack(spacing: DesignSystem.Spaces.oneAndMicro) {
                            HATileIcon(icon: icon, color: iconColor)
                            HATileInfo(primary: primary, secondary: secondary, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spaces.oneAndMicro)
                .padding(.vertical, vertical ? DesignSystem.Spaces.oneAndMicro : .zero)
                // Only the horizontal row needs the floor, and only it can be shorter than one:
                // an icon is 36pt against a 56pt row. A minimum-only flexible frame resolves to its
                // minimum when the height proposal is zero, which would cap the vertical tile —
                // taller than 56pt by construction — and leave its content hanging out of the card.
                .frame(minHeight: vertical ? nil : Self.rowHeight)
                // The tap target and the combined accessibility element cover the icon and info
                // only. `features` holds interactive controls — sliders, selects, buttons — and
                // combining them into the tile would leave them unfocusable and put the tile's
                // button trait in competition with theirs.
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(onTap == nil ? [] : .isButton)
                features
                    .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
                    .padding(.bottom, DesignSystem.Spaces.oneAndHalf)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

public extension HATileCard where Features == EmptyView {
    /// A tile with no controls under it.
    init(
        icon: MaterialDesignIcons,
        color: Color = .haDisabled,
        primary: String,
        secondary: String? = nil,
        vertical: Bool = false,
        isActive: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.init(
            icon: icon,
            color: color,
            primary: primary,
            secondary: secondary,
            vertical: vertical,
            isActive: isActive,
            onTap: onTap,
            features: { EmptyView() }
        )
    }
}

#Preview("Horizontal") {
    VStack(spacing: DesignSystem.Spaces.one) {
        HATileCard(icon: .lightbulbIcon, primary: "Ceiling light", secondary: "Off")
        HATileCard(
            icon: .lightbulbOnIcon,
            color: .haWarningColor,
            primary: "Ceiling light",
            secondary: "On · 60%",
            isActive: true
        )
        HATileCard(
            icon: .lightbulbOnIcon,
            color: .haWarningColor,
            primary: "Ceiling light",
            secondary: "On · 60%",
            isActive: true
        ) {
            HAControlSlider(value: .constant(60))
        }
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

#Preview("Vertical") {
    HStack(spacing: DesignSystem.Spaces.one) {
        HATileCard(icon: .lightbulbIcon, primary: "Ceiling", secondary: "Off", vertical: true)
        HATileCard(
            icon: .thermometerIcon,
            color: .haPrimary,
            primary: "Thermostat",
            secondary: "21 °C",
            vertical: true,
            isActive: true
        )
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HATileCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-tile-card" }
}

#endif
