import Foundation
import PromiseKit
@testable import Shared
import XCTest

final class EmptyTagManagerTests: XCTestCase {
    func testNothingIsAvailableWithoutNFC() {
        let manager = EmptyTagManager()

        XCTAssertFalse(manager.isNFCAvailable)
        assertRejectedAsUnavailable(manager.readNFC())
        assertRejectedAsUnavailable(manager.writeNFC(value: "tag"))
        assertRejectedAsUnavailable(manager.writeRandomNFC())
        assertRejectedAsUnavailable(manager.writeNFC(
            deeplink: URL(string: "homeassistant://navigate/lovelace")!,
            alertMessage: "Hold near a tag"
        ))

        guard case .unhandled = manager.handle(userActivity: NSUserActivity(activityType: "test")) else {
            return XCTFail("expected an unhandled activity")
        }
    }

    func testFiringAnEventWithoutServersSucceeds() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager()

        let fired = expectation(description: "event fired")
        EmptyTagManager().fireEvent(tag: "tag-id").done {
            fired.fulfill()
        }.catch { error in
            XCTFail("unexpected error \(error)")
        }
        wait(for: [fired], timeout: 5)
    }

    func testErrorDescriptions() {
        XCTAssertEqual(TagManagerError.nfcUnavailable.errorDescription, L10n.Nfc.notAvailable)
        XCTAssertEqual(TagManagerError.notHomeAssistantTag.errorDescription, L10n.Nfc.Read.Error.notHomeAssistant)
        XCTAssertEqual(TagManagerError.invalidURL.errorDescription, L10n.Nfc.Write.Error.invalidUrl)
    }

    private func assertRejectedAsUnavailable<T>(
        _ promise: Promise<T>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let rejected = expectation(description: "rejected")
        promise.done { _ in
            XCTFail("expected a rejection", file: file, line: line)
        }.catch { error in
            XCTAssertEqual(error as? TagManagerError, .nfcUnavailable, file: file, line: line)
            rejected.fulfill()
        }
        wait(for: [rejected], timeout: 5)
    }
}
