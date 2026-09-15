#if !os(watchOS)
import SwiftUI

/// A media player as its now-playing card: what it is playing and the controls to change it.
public struct HomeMediaControlCardView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomeMediaControlCardConfig

    public init(config: HomeMediaControlCardConfig) {
        self.config = config
    }

    public var body: some View {
        if let presentation = context.presentation(of: config.entityId) {
            let state = context.registry.state(config.entityId)
            HAMediaControlCard(
                name: presentation.primary,
                icon: presentation.icon,
                title: state?.attributes.mediaTitle,
                subtitle: state?.attributes.mediaTitle == nil ? nil : presentation.secondary,
                accent: presentation.color,
                isPlaying: state?.state == "playing",
                onPlayPause: {
                    context.perform(.performAction(HomeServiceCall(
                        service: "media_player.media_play_pause",
                        entityId: config.entityId
                    )))
                },
                onPrevious: {
                    context.perform(.performAction(HomeServiceCall(
                        service: "media_player.media_previous_track",
                        entityId: config.entityId
                    )))
                },
                onNext: {
                    context.perform(.performAction(HomeServiceCall(
                        service: "media_player.media_next_track",
                        entityId: config.entityId
                    )))
                },
                onMore: { context.perform(.moreInfo(config.entityId)) }
            )
        }
    }
}

#Preview {
    HomeMediaControlCardView(config: HomeMediaControlCardConfig(entityId: "media_player.living_room"))
        .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
        .padding()
        .background(Color.haSecondaryBackground)
}
#endif
