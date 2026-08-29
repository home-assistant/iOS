#if !os(watchOS)
import HAIconic
import SwiftUI

/// A light as a single large bulb: the icon tinted by the light's own colour, the name beneath, and
/// an overflow control in the corner. The SwiftUI counterpart of the frontend's `hui-light-card`.
///
/// The icon carries the state — bright when on, dim when off, grey when unavailable — which is why
/// the caller passes the colour rather than a boolean.
public struct HALightCard: View {
    private let name: String
    private let icon: MaterialDesignIcons
    private let color: Color
    private let secondary: String?
    private let onTap: (() -> Void)?
    private let onMore: (() -> Void)?

    /// - Parameter secondary: A line under the name, which the frontend uses to say "Unavailable"
    ///   above the entity's name.
    public init(
        name: String,
        icon: MaterialDesignIcons = .lightbulbIcon,
        color: Color = .haWarningColor,
        secondary: String? = nil,
        onTap: (() -> Void)? = nil,
        onMore: (() -> Void)? = nil
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.secondary = secondary
        self.onTap = onTap
        self.onMore = onMore
    }

    public var body: some View {
        HACard {
            VStack(spacing: DesignSystem.Spaces.two) {
                if let onMore {
                    Button(action: onMore) {
                        MaterialDesignIconsImage(icon: .dotsVerticalIcon, size: 24)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel(Text(HADesignSystemEnvironment.current.strings.moreInformation))
                }
                MaterialDesignIconsImage(icon: icon, size: 80)
                    .foregroundStyle(color)
                VStack(spacing: .zero) {
                    if let secondary {
                        Text(secondary)
                            .font(DesignSystem.Font.body)
                    }
                    Text(name)
                        .font(DesignSystem.Font.body)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spaces.two)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HALightCard(name: "Bed Light", onMore: {})
        HALightCard(name: "Dining Room", color: .haWarningColor.opacity(0.6), onMore: {})
        HALightCard(name: "Lost Light", color: .haDisabled, secondary: "Unavailable", onMore: {})
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HALightCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-light-card" }
}

#endif
