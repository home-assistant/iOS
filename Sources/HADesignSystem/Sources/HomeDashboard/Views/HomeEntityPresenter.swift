#if !os(watchOS)
import HAIconic
import SwiftUI

/// Turns an entity's state into something to draw. Handed in rather than implemented here: the app
/// already knows how to name a state in the user's language, which icon a device class carries and
/// what colour a light is — this package would only be guessing at all three.
///
/// ``preview`` is the stand-in the gallery and the package's own previews use.
public struct HomeEntityPresenter {
    public let presentation: (HomeEntityState, HomeRegistry) -> HomeEntityPresentation
    /// The latest frame of a camera, when the app has one. Without it a camera falls back to a tile.
    public let cameraImage: (String) -> Image?

    public init(
        presentation: @escaping (HomeEntityState, HomeRegistry) -> HomeEntityPresentation,
        cameraImage: @escaping (String) -> Image? = { _ in nil }
    ) {
        self.presentation = presentation
        self.cameraImage = cameraImage
    }

    public func callAsFunction(_ state: HomeEntityState, in registry: HomeRegistry) -> HomeEntityPresentation {
        presentation(state, registry)
    }

    /// Enough of a presenter to draw the sample home: the icon the entity carries or a per-domain
    /// one, the frontend's state colours, and the raw state as its own caption. The app replaces it
    /// with one that translates.
    public static let preview = HomeEntityPresenter { state, registry in
        let registration = registry.entity(state.id)
        let iconName = state.attributes.icon ?? registration?.icon
        let isActive = HomeStateActivity.isActive(domain: state.domain, state: state.state)
        return HomeEntityPresentation(
            icon: HomeDashboardIconName.icon(iconName, fallback: HomeDomainIcon.icon(for: state)),
            color: HomeStateColor.color(for: state),
            primary: HomeEntityNameFormatter.name(of: state),
            secondary: HomeStateCaption.caption(for: state),
            isActive: isActive,
            isUnavailable: state.isUnavailable
        )
    }
}
#endif
