@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit

/// Covers the list of destinations "Add entity to" puts in front of someone: only the ones this
/// device has, and only the ones that can show what is being added.
@MainActor
@Suite(.serialized)
struct EntityAddToDestinationOptionsProviderTests {
    /// A Mac has no CarPlay quick access and no watch paired the way a phone does, so its only
    /// destination is its own toolbar.
    @Test("A Mac is offered its toolbar and nothing else")
    func aMacIsOfferedItsToolbarAlone() {
        guard #available(iOS 17.0, *) else { return }
        withCatalyst(true) {
            #expect(EntityAddToDestinationOptionsProvider.destinations(showing: nil) == [.macToolbar])
        }
    }

    /// The Mac toolbar is Catalyst's alone, so it is never offered anywhere else. CarPlay turns on the
    /// device idiom, which the test host decides, so only the rule is checked for it.
    @Test("Anything that is not a Mac is never offered the Mac toolbar")
    func aPhoneIsNotOfferedTheMacToolbar() {
        guard #available(iOS 17.0, *) else { return }
        withCatalyst(false) {
            let destinations = EntityAddToDestinationOptionsProvider.destinations(showing: nil)

            #expect(!destinations.contains(.macToolbar))
            #expect(destinations.contains(.appleWatch))
            #expect(destinations.contains(.carPlay) == (UIDevice.current.userInterfaceIdiom == .phone))
        }
    }

    /// Once an entity is chosen, a destination that has no row to draw it in drops out: the watch and
    /// CarPlay each render a fixed set of domains, and a camera is in neither.
    @Test("A destination that cannot show the entity is not offered")
    func aDestinationThatCannotShowTheEntityIsNotOffered() {
        guard #available(iOS 17.0, *) else { return }
        withCatalyst(false) {
            #expect(EntityAddToDestinationOptionsProvider.destinations(showing: "camera.porch").isEmpty)
            #expect(
                EntityAddToDestinationOptionsProvider.destinations(showing: "light.kitchen")
                    .contains(.appleWatch)
            )
        }
    }

    /// The Mac toolbar puts every entity behind a more info dialog, so nothing is off limits there.
    @Test("The Mac toolbar takes an entity the other destinations cannot show")
    func theMacToolbarTakesAnything() {
        guard #available(iOS 17.0, *) else { return }
        withCatalyst(true) {
            #expect(EntityAddToDestinationOptionsProvider.destinations(showing: "camera.porch") == [.macToolbar])
        }
    }

    /// Through the provider itself rather than the filter behind it: nothing has chosen an entity, so
    /// this is the list Siri is offered when it asks for the destination first.
    @Test("The provider offers the device's destinations")
    func theProviderOffersTheDevicesDestinations() async throws {
        guard #available(iOS 17.0, *) else { return }
        let previous = Current.isCatalyst
        defer { Current.isCatalyst = previous }
        Current.isCatalyst = true

        let destinations = try await EntityAddToDestinationOptionsProvider().results()

        #expect(destinations == [.macToolbar])
    }

    private func withCatalyst(_ isCatalyst: Bool, perform work: () -> Void) {
        let previous = Current.isCatalyst
        defer { Current.isCatalyst = previous }
        Current.isCatalyst = isCatalyst
        work()
    }
}
