@testable import HomeAssistant
@testable import Shared
import Testing

struct EntityAddToDestinationAppEnumTests {
    @Test("The watch takes the domains its home screen can render")
    func watchSupportsWatchAddableDomains() {
        #expect(EntityAddToDestinationAppEnum.appleWatch.supports(entityId: "light.kitchen"))
        #expect(!EntityAddToDestinationAppEnum.appleWatch.supports(entityId: "camera.porch"))
    }

    @Test("CarPlay takes the domains quick access can render")
    func carPlaySupportsCarPlayDomains() {
        #expect(EntityAddToDestinationAppEnum.carPlay.supports(entityId: "cover.garage"))
        #expect(!EntityAddToDestinationAppEnum.carPlay.supports(entityId: "camera.porch"))
    }

    /// Every toolbar item opens a more info dialog, which every entity has.
    @Test("The Mac toolbar takes any domain the app models")
    func macToolbarSupportsAnyKnownDomain() {
        #expect(EntityAddToDestinationAppEnum.macToolbar.supports(entityId: "camera.porch"))
        #expect(EntityAddToDestinationAppEnum.macToolbar.supports(entityId: "light.kitchen"))
    }

    /// A domain the app does not model has no icon, no row and no more info dialog to open, so it
    /// fails even where any modelled entity would be accepted.
    @Test("A domain the app does not model is refused everywhere")
    func unknownDomainIsRefused() {
        for destination in EntityAddToDestinationAppEnum.allCases {
            #expect(!destination.supports(entityId: "made_up_domain.thing"))
            #expect(!destination.supports(entityId: "no_dot_at_all"))
        }
    }

    /// The intent's spoken answers name the destination, and they should call it what the frontend's
    /// own "Add to" sheet calls it.
    @Test("Destinations are named the way the Add to sheet names them")
    func destinationNamesMatchTheFrontendSheet() {
        #expect(EntityAddToDestinationAppEnum.appleWatch.localizedName == L10n.WebView.AddTo.Option.AppleWatch.title)
        #expect(EntityAddToDestinationAppEnum.carPlay.localizedName == L10n.WebView.AddTo.Option.CarPlay.title)
        #expect(EntityAddToDestinationAppEnum.macToolbar.localizedName == L10n.WebView.AddTo.Option.MacToolbar.title)
    }
}
