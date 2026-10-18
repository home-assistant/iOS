#if !os(watchOS)
import HAIconic
import SwiftUI

/// A card that is one big button: a large icon over a name, optionally with the state under it. The
/// SwiftUI counterpart of the frontend's `hui-button-card`.
public struct HAButtonCard: View {
    private let name: String?
    private let icon: MaterialDesignIcons?
    private let color: Color
    private let state: String?
    private let action: () -> Void

    /// - Parameters:
    ///   - name: Omit to show only the icon, the frontend's `show_name: false`.
    ///   - icon: Omit to show only the text, its `show_icon: false`.
    ///   - state: Shown under the name when the card is wired to an entity.
    public init(
        name: String? = nil,
        icon: MaterialDesignIcons? = nil,
        color: Color = .haDisabled,
        state: String? = nil,
        action: @escaping () -> Void
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.state = state
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HACard {
                VStack(spacing: DesignSystem.Spaces.one) {
                    if let icon {
                        MaterialDesignIconsImage(icon: icon, size: 48)
                            .foregroundStyle(color)
                    }
                    if let name {
                        Text(name)
                            .font(DesignSystem.Font.body)
                            .lineLimit(1)
                    }
                    if let state {
                        Text(state)
                            .font(DesignSystem.Font.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spaces.three)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(optional: name)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAButtonCard(name: "Ceiling light", icon: .lightbulbIcon) {}
        HAButtonCard(name: "Ceiling light", icon: .lightbulbOnIcon, color: .haWarningColor, state: "On") {}
        HAButtonCard(icon: .powerIcon) {}
        HAButtonCard(name: "No icon") {}
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAButtonCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-button-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
