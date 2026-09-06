import CarPlay
@testable import HomeAssistant
@testable import Shared
import XCTest

final class CarPlayOperationAlertTests: XCTestCase {
    func testTheAlertCarriesTheErrorsTitleVariants() {
        let error = CarPlayOperationError.noConnection

        let alert = CarPlayOperationAlert.makeAlertTemplate(for: error, onDismiss: {})

        XCTAssertEqual(alert.titleVariants, error.alertTitleVariants)
    }

    func testTheAlertOffersASingleDismissAction() {
        let alert = CarPlayOperationAlert.makeAlertTemplate(for: .timedOut, onDismiss: {})

        XCTAssertEqual(alert.actions.count, 1)
        XCTAssertEqual(alert.actions.first?.title, L10n.Alerts.Confirm.ok)
    }

    func testDismissingTheAlertRunsTheDismissHandler() {
        let dismissed = expectation(description: "dismiss handler ran")
        let alert = CarPlayOperationAlert.makeAlertTemplate(for: .noConnection) {
            dismissed.fulfill()
        }

        guard let action = alert.actions.first else {
            XCTFail("Expected a dismiss action")
            return
        }
        action.handler(action)

        wait(for: [dismissed], timeout: 1)
    }

    /// A failure raised before CarPlay handed the scene an interface controller still has to log
    /// rather than trap.
    func testPresentingWithoutAnInterfaceControllerIsANoOp() {
        CarPlayOperationAlert.present(.noConnection, on: nil)
    }
}
