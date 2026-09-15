#if !os(watchOS)
import SwiftUI

/// What sits beside a heading: a reading, or the button that acts on the whole section.
public struct HomeHeadingBadgeView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomeHeadingBadgeConfig

    public init(config: HomeHeadingBadgeConfig) {
        self.config = config
    }

    public var body: some View {
        switch config {
        case let .entity(entity):
            HomeEntityBadgeView(config: entity)
        case let .button(button):
            HABadge(
                icon: HomeDashboardIconName.icon(button.icon),
                color: HomeDashboardNamedColor.color(button.color) ?? .secondary,
                action: { context.perform(button.tapAction) }
            ) {
                Text(button.text)
            }
        }
    }
}

#Preview {
    HomeHeadingBadgeView(config: .entity(HomeEntityBadgeConfig(entityId: "sensor.bedroom_window_battery")))
        .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
        .padding()
        .background(Color.haSecondaryBackground)
}

#endif
