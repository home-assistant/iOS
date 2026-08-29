#if !os(watchOS)
import HAIconic
import SwiftUI

/// The centred placeholder for a surface with nothing to show: an icon, a heading, an optional
/// description and optional actions. The SwiftUI counterpart of the frontend's `ha-empty-state`.
public struct HAEmptyStateView<Actions: View>: View {
    private let icon: MaterialDesignIcons?
    private let heading: String?
    private let description: String?
    private let actions: Actions

    /// - Parameter actions: Controls that help the user fill the surface, e.g. an "Add" button.
    public init(
        icon: MaterialDesignIcons? = nil,
        heading: String? = nil,
        description: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.icon = icon
        self.heading = heading
        self.description = description
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spaces.four) {
            if let icon {
                MaterialDesignIconsImage(icon: icon, size: 64)
                    .foregroundStyle(.secondary)
            }
            if let heading {
                Text(heading)
                    .font(DesignSystem.Font.title3)
            }
            if let description {
                Text(description)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
            }
            actions
        }
        .multilineTextAlignment(.center)
        // The frontend caps the column at 500px so long copy stays readable.
        .frame(maxWidth: 500)
        .padding(.horizontal, DesignSystem.Spaces.four)
        .padding(.vertical, DesignSystem.Spaces.eight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public extension HAEmptyStateView where Actions == EmptyView {
    /// An empty state with nothing for the user to do about it.
    init(
        icon: MaterialDesignIcons? = nil,
        heading: String? = nil,
        description: String? = nil
    ) {
        self.init(icon: icon, heading: heading, description: description, actions: { EmptyView() })
    }
}

#Preview("With action") {
    HAEmptyStateView(
        icon: .packageVariantIcon,
        heading: "No automations yet",
        description: "Automations react to what happens in your home. Create one to get started."
    ) {
        Button("Create automation") {}
            .buttonStyle(.primaryButton)
    }
}

#Preview("Heading only") {
    HAEmptyStateView(icon: .databaseOffOutlineIcon, heading: "Nothing recorded")
}

extension HAEmptyStateView: FrontendComponent {
    public static var frontendComponentName: String { "ha-empty-state" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
