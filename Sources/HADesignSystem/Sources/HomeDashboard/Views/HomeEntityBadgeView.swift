#if !os(watchOS)
import SwiftUI

/// An entity's reading as a badge — an area's temperature over its screen, a device's battery beside
/// its name.
public struct HomeEntityBadgeView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomeEntityBadgeConfig

    public init(config: HomeEntityBadgeConfig) {
        self.config = config
    }

    public var body: some View {
        if let presentation = context.presentation(of: config.entityId) {
            HABadge(
                icon: presentation.icon,
                color: HomeDashboardNamedColor.color(config.color) ?? presentation.color,
                action: config.tapAction.map { action in { context.perform(action) } }
            ) {
                Text(presentation.secondary ?? presentation.primary)
            }
        }
    }
}

#Preview {
    HStack {
        HomeEntityBadgeView(config: HomeEntityBadgeConfig(entityId: "sensor.living_room_temperature", color: "red"))
        HomeEntityBadgeView(config: HomeEntityBadgeConfig(entityId: "sensor.living_room_humidity", color: "indigo"))
    }
    .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
    .padding()
    .background(Color.haSecondaryBackground)
}

#endif
