import Foundation
@testable import HomeAssistant
import Shared
import Testing

@MainActor
struct DeeplinkViewModelTests {
    private let scheme = AppConstants.deeplinkURL.absoluteString

    @Test func testDeeplinkForPageWithoutServer() {
        let sut = DeeplinkViewModel(target: .page(path: "lovelace/0"), serverName: "Home")

        #expect(sut.deeplink == "\(scheme)navigate/lovelace/0")
        #expect(sut.description == L10n.Deeplink.Page.description)
    }

    @Test func testDeeplinkForPageIncludingServer() {
        let sut = DeeplinkViewModel(target: .page(path: "lovelace/0"), serverName: "Home")
        sut.includeServer = true

        #expect(sut.deeplink == "\(scheme)navigate/lovelace/0?server=Home")
    }

    @Test func testDeeplinkForEntityIncludingServer() {
        let sut = DeeplinkViewModel(target: .entity(id: "light.kitchen"), serverName: "Home")
        sut.includeServer = true

        #expect(sut.deeplink == "\(scheme)navigate/?more-info-entity-id=light.kitchen&server=Home")
        #expect(sut.description == L10n.Deeplink.description)
    }
}
