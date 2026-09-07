import Foundation
@testable import HomeAssistant
import Shared
import Testing

struct DeeplinkTargetTests {
    private let scheme = AppConstants.deeplinkURL.absoluteString

    @Test func testPageFromURLStripsHostAndExternalAuth() throws {
        let url = try #require(URL(string: "https://home.local:8123/lovelace/0?external_auth=1"))

        #expect(DeeplinkTarget.page(from: url) == .page(path: "lovelace/0"))
    }

    @Test func testPageFromURLKeepsOtherQueryItems() throws {
        let url = try #require(URL(string: "https://home.local/config/devices/dashboard?external_auth=1&historyBack=1"))

        #expect(DeeplinkTarget.page(from: url) == .page(path: "config/devices/dashboard?historyBack=1"))
    }

    @Test func testPageFromRootURLHasEmptyPath() throws {
        let url = try #require(URL(string: "https://home.local/"))

        #expect(DeeplinkTarget.page(from: url) == .page(path: ""))
    }

    @Test func testPageFromURLKeepsPercentEncoding() throws {
        let url = try #require(URL(string: "https://home.local/lovelace/my%20view"))

        #expect(DeeplinkTarget.page(from: url) == .page(path: "lovelace/my%20view"))
    }

    @Test func testLocalizedDescription() {
        #expect(DeeplinkTarget.entity(id: "light.kitchen").localizedDescription == L10n.Deeplink.description)
        #expect(DeeplinkTarget.page(path: "lovelace/0").localizedDescription == L10n.Deeplink.Page.description)
    }

    @Test func testEntityURLWithoutServer() {
        let url = DeeplinkTarget.entity(id: "light.kitchen").url(serverName: nil)?.absoluteString

        #expect(url == "\(scheme)navigate/?more-info-entity-id=light.kitchen")
    }

    @Test func testEntityURLWithServer() {
        let url = DeeplinkTarget.entity(id: "light.kitchen").url(serverName: "My Home")?.absoluteString

        #expect(url == "\(scheme)navigate/?more-info-entity-id=light.kitchen&server=My%20Home")
    }

    @Test func testPageURLWithoutServer() {
        let url = DeeplinkTarget.page(path: "lovelace/0").url(serverName: nil)?.absoluteString

        #expect(url == "\(scheme)navigate/lovelace/0")
    }

    @Test func testPageURLWithServer() {
        let url = DeeplinkTarget.page(path: "lovelace/0?edit=1").url(serverName: "My Home")?.absoluteString

        #expect(url == "\(scheme)navigate/lovelace/0?edit=1&server=My%20Home")
    }
}
