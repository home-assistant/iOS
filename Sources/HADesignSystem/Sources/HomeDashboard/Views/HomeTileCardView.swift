#if !os(watchOS)
import HAIconic
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
                icon: icon(presentation),
                color: presentation.color,
                primary: config.name ?? presentation.primary,
                secondary: secondary(presentation),
                vertical: config.isVertical,
                isActive: presentation.isActive,
                onTap: { context.perform(config.tapAction ?? .moreInfo(config.entityId)) },
                features: { HomeTileFeatureView(feature: config.feature, entityId: config.entityId) }
            )
        }
    }

    private func icon(_ presentation: HomeEntityPresentation) -> MaterialDesignIcons {
        guard let icon = config.icon else {
            return presentation.icon
        }
        return HomeDashboardIconName.icon(icon, fallback: presentation.icon)
    }

    /// The second line: whichever parts the strategy asked for, in its order.
    private func secondary(_ presentation: HomeEntityPresentation) -> String? {
        guard !config.hidesState else {
            return nil
        }
        let parts = config.stateContent.compactMap { content -> String? in
            switch content {
            case .state:
                presentation.secondary
            case .temperature:
                temperature
            case .areaName:
                context.registry.context(of: config.entityId).area?.name
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// What it is like outside, for the weather tile. A weather entity reports that as
    /// `temperature`, which is the same attribute a thermostat uses for what it is *set* to — hence
    /// both being read here.
    private var temperature: String? {
        guard let state = context.registry.state(config.entityId),
              let value = state.attributes.targetTemperature ?? state.attributes.currentTemperature else {
            return nil
        }
        return value.formatted(.number.precision(.fractionLength(0 ... 1))) + "°"
    }
}

#Preview {
    HomeTileCardView(config: HomeTileCardConfig(entityId: "light.living_room_ceiling"))
        .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
        .padding()
        .background(Color.haSecondaryBackground)
}
#endif
