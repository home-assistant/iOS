import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class OnboardingAuthStepConfigTests: XCTestCase {
    private var step: OnboardingAuthStepConfig!
    private var api: FakeHomeAssistantAPI!
    private var connection: HAMockConnection!
    private var presenter: OnboardingAuthPresenter!

    override func setUp() {
        super.setUp()

        connection = HAMockConnection()
        api = FakeHomeAssistantAPI(server: .fake())
        api.connection = connection
        presenter = OnboardingAuthPresenter()

        step = OnboardingAuthStepConfig(api: api, presenter: presenter)
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

    func testPerformSendsThroughTheSignedInURL() {
        _ = step.perform(point: .afterRegister)

        XCTAssertEqual(api.getConfigOverrideURL, URL(string: "http://homeassistant.local:8123"))
    }

    func testSignedInURLPrefersTheInternalURL() {
        var connection = ServerInfo.fake().connection
        connection.set(address: URL(string: "http://192.168.1.10:8123/"), for: .internal)
        connection.set(address: URL(string: "https://example.com"), for: .external)
        connection.cloudhookURL = URL(string: "https://hooks.nabu.casa/cloudhook-id")
        connection.set(address: URL(string: "https://ui.nabu.casa"), for: .remoteUI)

        XCTAssertEqual(OnboardingAuthStepConfig.signedInURL(of: connection), URL(string: "http://192.168.1.10:8123"))
    }

    func testSignedInURLFallsBackToTheExternalURL() {
        var connection = ServerInfo.fake().connection
        connection.set(address: nil, for: .internal)
        connection.set(address: URL(string: "https://example.com"), for: .external)

        XCTAssertEqual(OnboardingAuthStepConfig.signedInURL(of: connection), URL(string: "https://example.com"))
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
    var getConfigOverrideURL: URL?

    override func getConfig(overrideURL: URL? = nil) -> Promise<Void> {
        let (promise, resolver) = Promise<Void>.pending()
        getConfigResolver = resolver
        getConfigOverrideURL = overrideURL
        return promise
    }
}
