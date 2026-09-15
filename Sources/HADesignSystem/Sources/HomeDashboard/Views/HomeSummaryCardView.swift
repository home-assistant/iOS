#if !os(watchOS)
import SwiftUI

/// One of the overview's summaries: what it is about, and how much of it is going on. The renderer's
/// counterpart of the frontend's `home-summary` card.
public struct HomeSummaryCardView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomeSummaryCardConfig

    public init(config: HomeSummaryCardConfig) {
        self.config = config
    }

    public var body: some View {
        HATileCard(
            icon: HomeDashboardIconName.icon(config.summary.icon),
            color: HomeDashboardNamedColor.color(config.summary.colorName) ?? .haPrimary,
            primary: config.title,
            secondary: subtitle,
            isActive: isActive,
            onTap: config.tapAction.map { action in { context.perform(action) } }
        )
    }

    /// Whether the summary's colour comes through: something it counts is doing something.
    private var isActive: Bool {
        config.entityIds.contains { context.presentation(of: $0)?.isActive == true }
    }

    private var subtitle: String? {
        HomeSummarySubtitle.subtitle(
            for: config.summary,
            entityIds: config.entityIds,
            registry: context.registry,
            strings: context.strings
        )
    }
}

#Preview {
    HomeDashboardGrid {
        HomeSummaryCardView(config: HomeSummaryCardConfig(
            summary: .light,
            title: "Lights",
            entityIds: ["light.living_room_ceiling", "light.kitchen_counter", "light.bedroom_bedside"]
        ))
        .homeDashboardColumns(6)
        HomeSummaryCardView(config: HomeSummaryCardConfig(
            summary: .security,
            title: "Security",
            entityIds: ["lock.front_door"]
        ))
        .homeDashboardColumns(6)
    }
    .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
    .padding()
    .background(Color.haSecondaryBackground)
}
#endif
