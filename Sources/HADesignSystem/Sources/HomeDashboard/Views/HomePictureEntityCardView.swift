#if !os(watchOS)
import SwiftUI

/// A camera in a room. Shows the frame the app handed over; without one it falls back to a tile, so
/// the camera is still there to tap even before a picture arrives.
public struct HomePictureEntityCardView: View {
    @Environment(\.homeDashboard) private var context

    private let config: HomePictureEntityCardConfig

    public init(config: HomePictureEntityCardConfig) {
        self.config = config
    }

    public var body: some View {
        if let image = context.presenter.cameraImage(config.entityId) {
            HAPictureCard(
                image: image,
                name: config.name ?? context.presentation(of: config.entityId)?.primary,
                onTap: { context.perform(config.tapAction ?? .moreInfo(config.entityId)) }
            )
        } else {
            HomeTileCardView(config: HomeTileCardConfig(
                entityId: config.entityId,
                name: config.name,
                tapAction: config.tapAction
            ))
        }
    }
}

#Preview {
    HomePictureEntityCardView(config: HomePictureEntityCardConfig(entityId: "camera.doorbell"))
        .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
        .padding()
        .background(Color.haSecondaryBackground)
}

#endif
