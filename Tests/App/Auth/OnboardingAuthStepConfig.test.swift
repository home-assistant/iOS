import HAKit
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class OnboardingAuthStepConfigTests: XCTestCase {
    private var step: OnboardingAuthStepConfig!
    private var api: FakeHomeAssistantAPI!
    private var connection: HAMockConnection!
    private var sender: UIViewController!

    override func setUp() {
        super.setUp()

        connection = HAMockConnection()
        api = FakeHomeAssistantAPI(server: .fake())
        api.connection = connection
        sender = UIViewController()

        step = OnboardingAuthStepConfig(api: api, sender: sender)
    }

    func testSupportedPoints() {
        XCTAssertTrue(OnboardingAuthStepConfig.supportedPoints.contains(.afterRegister))
    }

    func testPerformSuccess() {
        let result = step.perform(point: .afterRegister)

        XCTAssertFalse(result.isResolved)
        api.getConfigResolver?.fulfill(())
        XCTAssertNoThrow(try hang(result))
    }

    func testPerformFailure() {
        let result = step.perform(point: .afterRegister)

        XCTAssertFalse(result.isResolved)
        api.getConfigResolver?.reject(TestError.any)
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .any)
        }
    }
}

private enum TestError: Error {
    case any
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {
    var getConfigResolver: Resolver<Void>?

    override func getConfig() -> Promise<Void> {
        let (promise, resolver) = Promise<Void>.pending()
        getConfigResolver = resolver
        return promise
    }
}
