#if !os(watchOS)
import SwiftUI

/// A section's heading with its badges — the renderer's counterpart of the frontend's `heading` card.
public struct HomeHeadingCardView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomeHeadingCardConfig

    public init(config: HomeHeadingCardConfig) {
        self.config = config
    }

    public var body: some View {
        // The strategy uses an empty heading as the air between a room's controls and its devices.
        // Drawing it would add a heading's height to that gap on top of the section spacing.
        if config.heading.isEmpty, config.badges.isEmpty {
            EmptyView()
        } else {
            heading
        }
    }

    private var heading: some View {
        HAHeadingCard(
            heading: config.heading,
            icon: config.icon.map { HomeDashboardIconName.icon($0) },
            style: config.style == .title ? .title : .subtitle,
            onTap: config.tapAction.map { action in { context.perform(action) } }
        ) {
            HStack(spacing: DesignSystem.Spaces.one) {
                ForEach(visibleBadges) { badge in
                    HomeHeadingBadgeView(config: badge)
                }
            }
        }
    }

    /// A button badge is only drawn while its condition holds — that is what makes the pair over a
    /// room's lights read as one control that changes rather than two that contradict each other.
    private var visibleBadges: [HomeHeadingBadgeConfig] {
        config.badges.filter { badge in
            switch badge {
            case .entity: true
            case let .button(button): button.visibility.isSatisfied(in: context.registry)
            }
        }
    }
}

#Preview {
    let registry = HomeDashboardSampleHome.registry
    return VStack(alignment: .leading) {
        HomeHeadingCardView(config: HomeHeadingCardConfig(
            id: "light",
            heading: "Lights",
            icon: "mdi:lamps",
            badges: [.button(HomeHeadingButtonBadgeConfig(
                id: "lights-state-on",
                icon: "mdi:power",
                text: "On",
                color: "orange",
                tapAction: .performAction(HomeServiceCall(service: "light.turn_off", areaId: "kitchen")),
                visibility: .anyOn(["light.kitchen_counter"])
            ))]
        ))
        HomeHeadingCardView(config: HomeHeadingCardConfig(
            id: "device",
            heading: "Window sensor",
            badges: [.entity(HomeEntityBadgeConfig(entityId: "sensor.bedroom_window_battery"))]
        ))
    }
    .environment(\.homeDashboard, HomeDashboardContext(registry: registry))
    .padding()
    .background(Color.haSecondaryBackground)
}

#endif
