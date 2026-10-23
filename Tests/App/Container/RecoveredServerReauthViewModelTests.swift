import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

@MainActor
final class RecoveredServerReauthViewModelTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousApis: [Identifier<Server>: HomeAssistantAPI]!
    private var previousIsCatalyst = false
    private var server: Server!
    private var state: OnboardingStateObservable!
    private var viewModel: RecoveredServerReauthViewModel!

    private let certificate = ClientCertificate(keychainIdentifier: "imported", displayName: "Imported")

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousApis = Current.cachedApis
        previousIsCatalyst = Current.isCatalyst
        let servers = FakeServerManager(initial: 0)
        server = servers.add(identifier: .init(rawValue: "server-1"), serverInfo: .fake())
        Current.servers = servers
        let api = HomeAssistantAPI(server: server)
        api.connection = HAMockConnection()
        Current.cachedApis = [server.identifier: api]
        Current.isCatalyst = false
        state = OnboardingStateObservable()
        viewModel = RecoveredServerReauthViewModel(server: server, state: state)
    }

    override func tearDown() {
        Current.servers = previousServers
        Current.cachedApis = previousApis
        Current.isCatalyst = previousIsCatalyst
        super.tearDown()
    }

    private func authDetails() throws -> OnboardingAuthDetails {
        try OnboardingAuthDetails(baseURL: URL(string: "http://homeassistant.local:8123")!)
    }

    func testAvailableURLTypesComeFromTheServer() {
        XCTAssertEqual(viewModel.availableReauthURLTypes, state.availableReauthURLTypes(for: server))
    }

    func testSelectingAServerHandsItToTheState() {
        viewModel.selectServer(server)

        XCTAssertEqual(state.screen, .webView(server, initialPath: nil))
    }

    func testLoginPresentsTheLoginViewModelUntilItResolves() throws {
        let settled = expectation(description: "login settled")

        let promise = try viewModel.login(authDetails())
        let loginViewModel = try XCTUnwrap(viewModel.loginViewModel)
        promise.catch(policy: .allErrors) { _ in settled.fulfill() }
        loginViewModel.cancel()

        wait(for: [settled], timeout: 5)
        XCTAssertNil(viewModel.loginViewModel)
    }

    func testImportingACertificateFulfillsTheRequestAndDismissesIt() throws {
        let fulfilled = expectation(description: "imported")

        let expected = certificate
        let promise = viewModel.importClientCertificate()
        let request = try XCTUnwrap(viewModel.clientCertificateRequest)
        promise.done { imported in
            XCTAssertEqual(imported, expected)
            fulfilled.fulfill()
        }.cauterize()
        request.complete(with: certificate)

        wait(for: [fulfilled], timeout: 5)
        XCTAssertNil(viewModel.clientCertificateRequest)
    }

    func testCancellingTheImportRejectsTheRequestAndDismissesIt() throws {
        let rejected = expectation(description: "cancelled")

        let promise = viewModel.importClientCertificate()
        promise.catch(policy: .allErrors) { error in
            XCTAssertTrue((error as? PMKError)?.isCancelled == true)
            rejected.fulfill()
        }
        viewModel.cancelCertificateImport()

        wait(for: [rejected], timeout: 5)
        XCTAssertNil(viewModel.clientCertificateRequest)
    }

    func testCancellingWithoutARequestDoesNothing() {
        viewModel.cancelCertificateImport()

        XCTAssertNil(viewModel.clientCertificateRequest)
    }

    func testTheImportIsASheetOnIOS() {
        Current.isCatalyst = false
        _ = viewModel.importClientCertificate()

        XCTAssertNotNil(viewModel.certificateImportSheetBinding.wrappedValue)
        XCTAssertFalse(viewModel.certificateImportPageBinding.wrappedValue)

        viewModel.certificateImportPageBinding.wrappedValue = true
        XCTAssertNotNil(viewModel.clientCertificateRequest)
        viewModel.certificateImportSheetBinding.wrappedValue = nil
        XCTAssertNil(viewModel.clientCertificateRequest)
    }

    func testTheImportIsAPageOnCatalyst() {
        Current.isCatalyst = true
        _ = viewModel.importClientCertificate()

        XCTAssertNil(viewModel.certificateImportSheetBinding.wrappedValue)
        XCTAssertTrue(viewModel.certificateImportPageBinding.wrappedValue)

        viewModel.certificateImportSheetBinding.wrappedValue = viewModel.clientCertificateRequest
        XCTAssertNotNil(viewModel.clientCertificateRequest)
        viewModel.certificateImportPageBinding.wrappedValue = false
        XCTAssertNil(viewModel.clientCertificateRequest)
    }

    func testReauthenticateAsksForTheCertificateThenLogsIn() throws {
        state.clientCertificateRequirement = { _ in .value(true) }
        let completed = expectation(description: "completed")

        viewModel.reauthenticate(using: .external) { result in
            guard case let .failure(error) = result else { return XCTFail("expected cancellation") }
            XCTAssertEqual(error as? RecoveredServerReauthenticationError, .cancelled)
            completed.fulfill()
        }

        let request = try awaitValue { viewModel.clientCertificateRequest }
        request.complete(with: certificate)
        let loginViewModel = try awaitValue { viewModel.loginViewModel }
        XCTAssertEqual(loginViewModel.authDetails.clientCertificate, certificate)
        loginViewModel.cancel()

        wait(for: [completed], timeout: 5)
        XCTAssertNil(viewModel.loginViewModel)
    }

    private func awaitValue<T>(_ read: () -> T?) throws -> T {
        for _ in 0 ..< 100 {
            if let value = read() { return value }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return try XCTUnwrap(read())
    }
}
