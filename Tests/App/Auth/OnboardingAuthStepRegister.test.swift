import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class OnboardingAuthStepRegisterTests: XCTestCase {
    private var step: OnboardingAuthStepRegister!
    private var api: FakeHomeAssistantAPI!
    private var connection: HAMockConnection!
    private var presenter: OnboardingAuthPresenter!

    override func setUp() {
        super.setUp()

        connection = HAMockConnection()
        api = FakeHomeAssistantAPI(server: .fake())
        api.connection = connection
        presenter = OnboardingAuthPresenter()

        step = OnboardingAuthStepRegister(api: api, presenter: presenter)
    }

    func testSupportedPoints() {
        XCTAssertTrue(OnboardingAuthStepRegister.supportedPoints.contains(.register))
    }

    func testPerformSuccess() {
        let result = step.perform(point: .register)

        XCTAssertFalse(result.isResolved)
        api.registerResolver?.fulfill(())
        XCTAssertNoThrow(try hang(result))
    }

    func testPerformFailure() {
        let result = step.perform(point: .register)

        XCTAssertFalse(result.isResolved)
        api.registerResolver?.reject(TestError.any)
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .any)
        }
    }
}

private enum TestError: Error {
    case any
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {
    var registerResolver: Resolver<Void>?
    override func register() -> Promise<Void> {
        let (promise, resolver) = Promise<Void>.pending()
        registerResolver = resolver
        return promise
    }
}
