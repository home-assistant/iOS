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

    func testAFailurePresentsAnAlertCarryingItsTitleVariants() {
        let presenter = FakeCarPlayAlertPresenter()

        CarPlayOperationAlert.present(.noConnection, on: presenter)

        XCTAssertEqual(presenter.presentedTemplates.count, 1)
        let alert = presenter.presentedTemplates.first as? CPAlertTemplate
        XCTAssertEqual(alert?.titleVariants, CarPlayOperationError.noConnection.alertTitleVariants)
    }

    /// A dead zone can catch several rows at once. CarPlay shows one modal at a time, and stacking
    /// alerts would leave the driver dismissing them one by one.
    func testASecondFailureDoesNotStackAnotherAlert() {
        let presenter = FakeCarPlayAlertPresenter()

        CarPlayOperationAlert.present(.noConnection, on: presenter)
        CarPlayOperationAlert.present(.timedOut, on: presenter)

        XCTAssertEqual(presenter.presentedTemplates.count, 1)
    }

    /// Once the driver dismisses, the next failure is worth showing again.
    func testAFailureAfterTheAlertIsDismissedPresentsAgain() {
        let presenter = FakeCarPlayAlertPresenter()

        CarPlayOperationAlert.present(.noConnection, on: presenter)
        presenter.dismissTemplate(animated: false, completion: nil)
        CarPlayOperationAlert.present(.timedOut, on: presenter)

        XCTAssertEqual(presenter.presentedTemplates.count, 2)
    }

    func testTheAlertsActionDismissesThePresentedTemplate() {
        let presenter = FakeCarPlayAlertPresenter()
        CarPlayOperationAlert.present(.noConnection, on: presenter)

        guard let alert = presenter.presentedTemplates.first as? CPAlertTemplate,
              let action = alert.actions.first else {
            XCTFail("Expected a presented alert with a dismiss action")
            return
        }
        action.handler(action)

        XCTAssertEqual(presenter.dismissCount, 1)
    }
}
