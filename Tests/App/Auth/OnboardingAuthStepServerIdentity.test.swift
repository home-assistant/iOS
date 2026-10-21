import Combine
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

final class OnboardingAuthStepServerIdentityTests: XCTestCase {
    private var presenter: OnboardingAuthPresenter!
    private var api: HomeAssistantAPI!
    private var cancellables = Set<AnyCancellable>()
    private var previousIsCatalyst: Bool!

    override func setUp() {
        super.setUp()
        previousIsCatalyst = Current.isCatalyst
        Current.isCatalyst = false
        Current.servers = FakeServerManager()
        presenter = OnboardingAuthPresenter()
        api = HomeAssistantAPI(server: .fake(identifier: "onboarding-server") {
            $0.remoteName = "Chalet"
            $0.instanceID = "instance-1"
            $0.connection.set(address: URL(string: "http://chalet.duckdns.org:8123"), for: .external)
        })
        cancellables.removeAll()
    }

    override func tearDown() {
        Current.isCatalyst = previousIsCatalyst
        cancellables.removeAll()
        super.tearDown()
    }

    private func addExistingServer(internalURL: URL?) {
        Current.servers.add(identifier: "existing-server", serverInfo: with(ServerInfo.fake()) {
            $0.remoteName = "Home"
            $0.instanceID = "instance-1"
            $0.connection.set(address: internalURL, for: .internal)
            $0.connection.set(address: nil, for: .external)
        })
    }

    private func onRequest(_ handle: @escaping (OnboardingServerIdentityRequest) -> Void) -> XCTestExpectation {
        let expectation = expectation(description: "server identity request")
        presenter.$serverIdentityRequest
            .compactMap { $0 }
            .first()
            .sink { request in
                DispatchQueue.main.async {
                    handle(request)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        return expectation
    }

    private var step: OnboardingAuthStepServerIdentity {
        OnboardingAuthStepServerIdentity(api: api, presenter: presenter)
    }

    func testSupportedPoints() {
        XCTAssertEqual(OnboardingAuthStepServerIdentity.supportedPoints, [.afterRegister])
    }

    func testNothingIsAskedWithoutAConflict() throws {
        presenter.serverIdentityDecision = .replace

        try hang(step.perform(point: .afterRegister))

        XCTAssertNil(presenter.serverIdentityRequest)
        XCTAssertNil(presenter.serverIdentityDecision)
    }

    func testNothingIsAskedForTheSameServer() throws {
        addExistingServer(internalURL: URL(string: "https://chalet.duckdns.org:8123"))

        try hang(step.perform(point: .afterRegister))

        XCTAssertNil(presenter.serverIdentityRequest)
        XCTAssertNil(presenter.serverIdentityDecision)
    }

    func testAsksAboutBothServersAndKeepsTheSeparateAnswer() throws {
        addExistingServer(internalURL: URL(string: "http://homeassistant.local:8123"))
        var asked: OnboardingServerIdentityRequest?
        let answered = onRequest { request in
            asked = request
            request.addAsSeparateServer()
        }

        try hang(step.perform(point: .afterRegister))
        wait(for: [answered], timeout: 10.0)

        let request = try XCTUnwrap(asked)
        XCTAssertEqual(
            request.newServer,
            ServerIdentityConflictingServer(name: "Chalet", address: "http://chalet.duckdns.org:8123")
        )
        XCTAssertEqual(
            request.existingServer,
            ServerIdentityConflictingServer(name: "Home", address: "http://homeassistant.local:8123")
        )
        XCTAssertEqual(presenter.serverIdentityDecision, .separate)
        XCTAssertNil(presenter.serverIdentityRequest)
    }

    func testKeepsTheReplaceAnswer() throws {
        addExistingServer(internalURL: URL(string: "http://homeassistant.local:8123"))
        let answered = onRequest { $0.replaceExistingServer() }

        try hang(step.perform(point: .afterRegister))
        wait(for: [answered], timeout: 10.0)

        XCTAssertEqual(presenter.serverIdentityDecision, .replace)
    }

    func testCancellingRejectsTheStep() {
        addExistingServer(internalURL: URL(string: "http://homeassistant.local:8123"))
        let answered = onRequest { $0.cancel() }

        XCTAssertThrowsError(try hang(step.perform(point: .afterRegister))) { error in
            guard case PMKError.cancelled = error else {
                return XCTFail("expected a cancellation, got \(error)")
            }
        }
        wait(for: [answered], timeout: 10.0)

        XCTAssertNil(presenter.serverIdentityDecision)
        XCTAssertNil(presenter.serverIdentityRequest)
    }

    /// Mac Catalyst pushes the question as a page, and answering it takes only that page off the stack.
    func testOnMacTheQuestionIsPushedAndPoppedOnceAnswered() throws {
        Current.isCatalyst = true
        presenter.path = [.serversList]
        addExistingServer(internalURL: URL(string: "http://homeassistant.local:8123"))
        let pushed = expectation(description: "pushed")
        presenter.$path
            .compactMap { path -> OnboardingServerIdentityRequest? in
                guard case let .serverIdentity(request) = path.last else { return nil }
                return request
            }
            .first()
            .sink { request in
                DispatchQueue.main.async {
                    request.addAsSeparateServer()
                    pushed.fulfill()
                }
            }
            .store(in: &cancellables)

        try hang(step.perform(point: .afterRegister))
        wait(for: [pushed], timeout: 10.0)

        XCTAssertNil(presenter.serverIdentityRequest)
        XCTAssertEqual(presenter.path, [.serversList])
        XCTAssertEqual(presenter.serverIdentityDecision, .separate)
    }
}
