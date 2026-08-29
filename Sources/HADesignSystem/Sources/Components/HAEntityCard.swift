#if !os(watchOS)
import HAIconic
import SwiftUI

/// A card leading with one entity's reading: its name and icon across the top, the value large
/// underneath. The SwiftUI counterpart of the frontend's `hui-entity-card`.
///
/// Takes plain strings rather than an entity — mapping state onto a name, an icon and a formatted
/// value is the app's job, the same split the widget components use.
public struct HAEntityCard: View {
    private let name: String
    private let icon: MaterialDesignIcons?
    private let color: Color
    private let value: String
    private let unit: String?
    private let footer: String?
    private let onTap: (() -> Void)?

    public init(
        name: String,
        icon: MaterialDesignIcons? = nil,
        color: Color = .haDisabled,
        value: String,
        unit: String? = nil,
        footer: String? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.value = value
        self.unit = unit
        self.footer = footer
        self.onTap = onTap
    }

    public var body: some View {
        HACard {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                HStack(alignment: .top) {
                    Text(name)
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: DesignSystem.Spaces.one)
                    if let icon {
                        MaterialDesignIconsImage(icon: icon, size: 24)
                            .foregroundStyle(color)
                    }
                }
                // The unit rides small against the value's baseline, as the frontend styles it
                // separately from the number.
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spaces.half) {
                    Text(value)
                        .font(.system(size: 28))
                    if let unit {
                        Text(unit)
                            .font(DesignSystem.Font.body)
                            .foregroundStyle(.secondary)
                    }
                }
                if let footer {
                    Text(footer)
                        .font(DesignSystem.Font.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DesignSystem.Spaces.two)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAEntityCard(name: "Living room", icon: .thermometerIcon, color: .haPrimary, value: "21.5", unit: "°C")
        HAEntityCard(name: "Humidity", value: "64", unit: "%", footer: "Updated 5 minutes ago")
        HAEntityCard(name: "Front door", icon: .doorIcon, value: "Closed")
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAEntityCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-entity-card" }
}

#endif
