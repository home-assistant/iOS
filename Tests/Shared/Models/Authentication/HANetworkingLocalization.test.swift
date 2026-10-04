import Foundation
@testable import Shared
import XCTest

final class HANetworkingLocalizationTests: XCTestCase {
    func testConnectionSecurityLevelDescriptions() {
        XCTAssertEqual(
            ConnectionSecurityLevel.undefined.description,
            L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.Undefined.title
        )
        XCTAssertEqual(
            ConnectionSecurityLevel.mostSecure.description,
            L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.MostSecure.title
        )
        XCTAssertEqual(
            ConnectionSecurityLevel.lessSecure.description,
            L10n.Settings.ConnectionSection.ConnectionAccessSecurityLevel.LessSecure.title
        )
    }

    func testURLTypeDescriptions() {
        XCTAssertEqual(
            ConnectionInfo.URLType.internal.description,
            L10n.Settings.ConnectionSection.InternalBaseUrl.title
        )
        XCTAssertEqual(
            ConnectionInfo.URLType.remoteUI.description,
            L10n.Settings.ConnectionSection.RemoteUiUrl.title
        )
        XCTAssertEqual(
            ConnectionInfo.URLType.external.description,
            L10n.Settings.ConnectionSection.ExternalBaseUrl.title
        )
        XCTAssertEqual(
            ConnectionInfo.URLType.none.description,
            L10n.Settings.ConnectionSection.NoBaseUrl.title
        )
    }

    func testPrivacyDescriptions() {
        XCTAssertEqual(
            ServerLocationPrivacy.never.localizedDescription,
            L10n.Settings.ConnectionSection.LocationSendType.Setting.never
        )
        XCTAssertEqual(
            ServerLocationPrivacy.exact.localizedDescription,
            L10n.Settings.ConnectionSection.LocationSendType.Setting.exact
        )
        XCTAssertEqual(
            ServerLocationPrivacy.zoneOnly.localizedDescription,
            L10n.Settings.ConnectionSection.LocationSendType.Setting.zoneOnly
        )
        XCTAssertEqual(
            ServerSensorPrivacy.all.localizedDescription,
            L10n.Settings.ConnectionSection.SensorSendType.Setting.all
        )
        XCTAssertEqual(
            ServerSensorPrivacy.none.localizedDescription,
            L10n.Settings.ConnectionSection.SensorSendType.Setting.none
        )
    }

    func testDefaultServerName() {
        XCTAssertEqual(ServerInfo.defaultName, L10n.Settings.StatusSection.LocationNameRow.placeholder)
    }

    func testTokenErrorDescriptions() {
        XCTAssertEqual(
            TokenManager.TokenError.tokenUnavailable.localizedDescription,
            L10n.TokenError.tokenUnavailable
        )
        XCTAssertEqual(TokenManager.TokenError.expired.localizedDescription, L10n.TokenError.expired)
        XCTAssertEqual(
            TokenManager.TokenError.connectionFailed.localizedDescription,
            L10n.TokenError.connectionFailed
        )
    }

    func testNoActiveURLError() {
        let error: Error = ServerConnectionError.noActiveURL("Home")

        XCTAssertEqual(error.localizedDescription, L10n.Network.Error.NoActiveUrl.description("Home"))
        XCTAssertTrue(error.isNoActiveURLError)
        XCTAssertFalse(TokenManager.TokenError.expired.isNoActiveURLError)
        XCTAssertFalse(URLError(.timedOut).isNoActiveURLError)
    }
}
