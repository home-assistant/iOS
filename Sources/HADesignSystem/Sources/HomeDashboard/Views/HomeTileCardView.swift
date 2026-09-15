#if !os(watchOS)
import SwiftUI

/// An entity as a tile — the renderer's counterpart of the strategy's `tile` card.
public struct HomeTileCardView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomeTileCardConfig

    public init(config: HomeTileCardConfig) {
        self.config = config
    }

    public var body: some View {
        if let presentation = context.presentation(of: config.entityId) {
            HATileCard(
                icon: config.icon.map { HomeDashboardIconName.icon($0, fallback: presentation.icon) } ?? presentation
                    .icon,
                color: presentation.color,
                primary: config.name ?? presentation.primary,
                secondary: config.hidesState ? nil : presentation.secondary,
                vertical: config.isVertical,
                isActive: presentation.isActive,
                onTap: { context.perform(config.tapAction ?? .moreInfo(config.entityId)) },
                features: { HomeTileFeatureView(feature: config.feature, entityId: config.entityId) }
            )
        }
    }
}

#Preview {
    HomeTileCardView(config: HomeTileCardConfig(entityId: "light.living_room_ceiling"))
        .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
        .padding()
        .background(Color.haSecondaryBackground)
}
#endif
