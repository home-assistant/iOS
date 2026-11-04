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

    override func tearDown() {
        // XCTest keeps this test case alive for the whole run, and an API left alive stays registered
        // with the app's sensor container, which every later sensor signal fans out to. A request the
        // test never answers would keep it alive through the step's promise chain.
        connection?.pendingRequests.removeAll()
        connection?.pendingSubscriptions.removeAll()
        step = nil
        api = nil
        connection = nil
        presenter = nil
        super.tearDown()
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
    override func register(deviceName: String? = nil) -> Promise<Void> {
        let (promise, resolver) = Promise<Void>.pending()
        registerResolver = resolver
        return promise
    }
}
