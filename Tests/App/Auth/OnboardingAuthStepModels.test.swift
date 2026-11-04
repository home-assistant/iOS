import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class OnboardingAuthStepModelsTests: XCTestCase {
    private var step: OnboardingAuthStepModels!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!
    private var presenter: OnboardingAuthPresenter!
    private var modelManager: FakeModelManager!

    override func setUp() {
        super.setUp()

        modelManager = FakeModelManager()
        Current.modelManager = modelManager

        connection = HAMockConnection()
        api = HomeAssistantAPI(server: .fake())
        api.connection = connection
        presenter = OnboardingAuthPresenter()

        step = OnboardingAuthStepModels(api: api, presenter: presenter)
    }

    override func tearDown() {
        super.tearDown()

        Current.modelManager = .init()
        // XCTest keeps this test case alive for the whole run, and an API left alive stays registered
        // with the app's sensor container, which every later sensor signal fans out to. A request the
        // test never answers would keep it alive through the step's promise chain.
        connection?.pendingRequests.removeAll()
        connection?.pendingSubscriptions.removeAll()
        step = nil
        api = nil
        connection = nil
        presenter = nil
        modelManager = nil
    }

    func testSupportedPoints() {
        XCTAssertTrue(OnboardingAuthStepModels.supportedPoints.contains(.afterRegister))
    }

    func testPerformSuccess() {
        modelManager.fetchResult = .value(())
        modelManager.expectedApis = [api]
        let result = step.perform(point: .afterRegister)
        XCTAssertNoThrow(try hang(result))
    }

    func testPerformFailure() {
        modelManager.fetchResult = .init(error: TestError.any)
        modelManager.expectedApis = [api]
        let result = step.perform(point: .afterRegister)
        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? TestError, .any)
        }
    }
}

private enum TestError: Error {
    case any
}

private class FakeModelManager: LegacyModelManager {
    var fetchResult: Promise<Void> = .value(())
    var expectedApis: [HomeAssistantAPI] = []

    override func fetch(
        definitions: [FetchDefinition] = FetchDefinition.defaults,
        apis: [HomeAssistantAPI] = Current.apis
    ) -> Promise<Void> {
        XCTAssertEqual(expectedApis.map(\.server), apis.map(\.server))
        return fetchResult
    }
}
