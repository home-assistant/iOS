import Foundation
import Intents
@testable import Shared
import XCTest

/// The Focus status iOS pushes to the Intents extension is recorded before the Focus sensors are
/// updated for every server.
final class FocusStatusIntentHandlerTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousIsAppExtension: Bool!
    private var previousSettleDelay: TimeInterval!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousIsAppExtension = Current.isAppExtension
        previousSettleDelay = FocusStatusIntentHandler.settleDelay

        // No servers, so there are no Focus sensors to send and the update settles immediately.
        Current.servers = FakeServerManager()
        Current.isAppExtension = true
        Current.focusStatus = FocusStatusWrapper()
        Current.focusStatus.receivedStatus.value = nil
        Current.date = { [now] in now }
        FocusStatusIntentHandler.settleDelay = 0
    }

    override func tearDown() {
        FocusStatusIntentHandler.settleDelay = previousSettleDelay
        Current.focusStatus.receivedStatus.value = nil
        Current.focusStatus = FocusStatusWrapper()
        Current.isAppExtension = previousIsAppExtension
        Current.servers = previousServers
        Current.date = Date.init
        super.tearDown()
    }

    func testFocusedStatusIsRecordedAndReportedAsSuccess() {
        let intent = INShareFocusStatusIntent(focusStatus: INFocusStatus(isFocused: true))

        let response = handle(intent)

        XCTAssertEqual(response?.code, .success)
        XCTAssertEqual(Current.focusStatus.lastReceived()?.isFocused, true)
        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastStartedDate, now)
    }

    func testEndedFocusIsRecordedWithWhenItEnded() {
        let intent = INShareFocusStatusIntent(focusStatus: INFocusStatus(isFocused: false))

        let response = handle(intent)

        XCTAssertEqual(response?.code, .success)
        XCTAssertEqual(Current.focusStatus.lastReceived()?.isFocused, false)
        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastEndedDate, now)
    }

    private func handle(_ intent: INShareFocusStatusIntent) -> INShareFocusStatusIntentResponse? {
        let completed = expectation(description: "handled")
        var received: INShareFocusStatusIntentResponse?
        FocusStatusIntentHandler().handle(intent: intent) { response in
            received = response
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
        return received
    }
}
