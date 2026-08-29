#if !os(watchOS)
import HAIconic
import SwiftUI

/// One line of an ``HAEntitiesCard``: a tinted icon, a name, and whatever control belongs on the
/// trailing edge. Covers the whole `hui-*-entity-row` family.
///
/// The frontend has a row type per domain — toggle, text, cover, climate, number, input — but they
/// are one shell with different trailing content, in the same way the card features are one control
/// each. What varies is the mapping from entity state, which is app work, so this takes the trailing
/// content as a builder rather than growing a case for every domain.
public struct HAEntityRow<Trailing: View>: View {
    private let name: String
    private let icon: MaterialDesignIcons?
    private let color: Color
    private let secondary: String?
    private let onTap: (() -> Void)?
    private let trailing: Trailing

    /// - Parameter secondary: A second line under the name, for a row that reports as well as acts.
    public init(
        name: String,
        icon: MaterialDesignIcons? = nil,
        color: Color = .haPrimary,
        secondary: String? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.secondary = secondary
        self.onTap = onTap
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            if let icon {
                MaterialDesignIconsImage(icon: icon, size: 24)
                    .foregroundStyle(color)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: .zero) {
                Text(name)
                    .font(DesignSystem.Font.body)
                    .lineLimit(1)
                if let secondary {
                    Text(secondary)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: DesignSystem.Spaces.one)
            trailing
        }
        // The row is as tall as a touch target even when its trailing control is only text.
        .frame(minHeight: 40)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .combine)
    }
}

public extension HAEntityRow where Trailing == Text {
    /// A row whose trailing content is the entity's state as plain text — the commonest kind.
    init(
        name: String,
        icon: MaterialDesignIcons? = nil,
        color: Color = .haPrimary,
        secondary: String? = nil,
        state: String,
        onTap: (() -> Void)? = nil
    ) {
        self.init(name: name, icon: icon, color: color, secondary: secondary, onTap: onTap) {
            Text(state)
        }
    }
}

public extension HAEntityRow where Trailing == Button<Text> {
    /// A row whose trailing content is a single action — "Activate", "Unlock".
    ///
    /// Plain accent text rather than a button style: the rendered `hui-entities-card` puts bare blue
    /// words there, and a padded pill in a 40pt row crowds out the entity's name.
    init(
        name: String,
        icon: MaterialDesignIcons? = nil,
        color: Color = .haPrimary,
        secondary: String? = nil,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        self.init(name: name, icon: icon, color: color, secondary: secondary) {
            Button(actionTitle, action: action)
        }
    }
}

#Preview {
    VStack(spacing: .zero) {
        HAEntityRow(name: "Paulus", icon: .accountIcon, color: .haSuccessColor, state: "Home")
        HAEntityRow(name: "Humidity", icon: .waterPercentIcon, state: "23.2 %")
        HAEntityRow(name: "Bed Light", icon: .lightbulbIcon, color: .haWarningColor) {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
        HAEntityRow(name: "Kitchen Lock", icon: .lockIcon, color: .haSuccessColor, actionTitle: "Unlock") {}
        HAEntityRow(name: "Ecobee", icon: .thermostatIcon, secondary: "Currently: 23 °C", state: "Idle")
        HAEntityRow(name: "Kitchen Window", icon: .windowShutterIcon, color: .haPrimary) {
            HStack(spacing: DesignSystem.Spaces.one) {
                MaterialDesignIconsImage(icon: .arrowUpIcon, size: 20)
                MaterialDesignIconsImage(icon: .stopIcon, size: 20)
                MaterialDesignIconsImage(icon: .arrowDownIcon, size: 20)
            }
        }
    }
    .padding()
}

extension HAEntityRow: FrontendComponent {
    public static var frontendComponentName: String { "hui-simple-entity-row" }
}

#endif
