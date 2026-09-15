#if !os(watchOS)
import SwiftUI

/// A device's entities as a list — what the other-devices view shows instead of a tile each.
public struct HomeEntitiesCardView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomeEntitiesCardConfig

    public init(config: HomeEntitiesCardConfig) {
        self.config = config
    }

    public var body: some View {
        HAEntitiesCard {
            ForEach(config.entityIds, id: \.self) { entityId in
                if let presentation = context.presentation(of: entityId) {
                    // Name on the left, state on the right, as the rendered `hui-entities-card`
                    // puts them.
                    HAEntityRow(
                        name: presentation.primary,
                        icon: presentation.icon,
                        color: presentation.isActive ? presentation.color : .haDisabled,
                        state: presentation.secondary ?? "",
                        onTap: { context.perform(.moreInfo(entityId)) }
                    )
                }
            }
        }
    }
}

#Preview {
    HomeEntitiesCardView(config: HomeEntitiesCardConfig(
        id: "printer",
        entityIds: ["sensor.printer_ink", "weather.home"]
    ))
    .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
    .padding()
    .background(Color.haSecondaryBackground)
}
#endif
