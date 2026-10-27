@testable import HomeAssistant
@testable import Shared
import XCTest

@MainActor
final class ThreadCredentialSharingModeViewModelTests: XCTestCase {
    private var sut: ThreadCredentialSharingModeViewModel!
    private var mockClient: SimulatorThreadClientService!

    override func setUpWithError() throws {
        mockClient = SimulatorThreadClientService()
        sut = .init(threadClientService: mockClient)
    }

    override func tearDownWithError() throws {
        sut = nil
        mockClient = nil
    }

    func test_loadCredentials_populates_credentials() async {
        await sut.loadCredentials()

        XCTAssertTrue(mockClient.retrieveAllCredentialsCalled)
        XCTAssertEqual(sut.credentials.count, 2)
        XCTAssertFalse(sut.isLoadingCredentials)
    }

    func test_loadCredentials_failure_clears_credentials() async {
        mockClient.retrieveAllCredentialsError = ThreadClientServiceError.credentialSharingModeUnavailable
        XCTAssertTrue(sut.isLoadingCredentials)

        await sut.loadCredentials()

        XCTAssertTrue(mockClient.retrieveAllCredentialsCalled)
        XCTAssertTrue(sut.credentials.isEmpty)
        XCTAssertFalse(sut.isLoadingCredentials)
    }

    func test_sanitizedExtendedPANID_strips_separators_and_prefix() {
        sut.extendedPANID = " 0xDE:AD-BE EF 00 11 22 33 "

        XCTAssertEqual(sut.sanitizedExtendedPANID, "deadbeef00112233")
        XCTAssertTrue(sut.isExtendedPANIDValid)
        XCTAssertTrue(sut.canEnableSharingMode)
    }

    func test_isExtendedPANIDValid_rejects_wrong_length_or_non_hex() {
        sut.extendedPANID = "deadbeef"
        XCTAssertFalse(sut.isExtendedPANIDValid)

        sut.extendedPANID = "deadbeef0011223g"
        XCTAssertFalse(sut.isExtendedPANIDValid)

        sut.extendedPANID = ""
        XCTAssertFalse(sut.canEnableSharingMode)
    }

    func test_select_fills_extendedPANID_and_resets_state() async {
        mockClient.enableCredentialSharingModeError = ThreadClientServiceError.credentialSharingModeUnavailable
        sut.extendedPANID = "deadbeef00112233"
        await sut.enableSharingMode()
        XCTAssertNotEqual(sut.state, .idle)

        let credential = ThreadCredential(
            networkName: "Home",
            networkKey: "key",
            extendedPANID: "0011223344556677",
            borderAgentID: "agent",
            macExtendedAddress: "mac",
            activeOperationalDataSet: "dataset",
            pskc: "pskc",
            channel: 25,
            panID: "pan"
        )
        sut.select(credential)

        XCTAssertEqual(sut.extendedPANID, "0011223344556677")
        XCTAssertEqual(sut.state, .idle)
    }

    func test_enableSharingMode_success_passes_sanitized_id() async {
        sut.extendedPANID = "DEAD BEEF 0011 2233"

        await sut.enableSharingMode()

        XCTAssertEqual(mockClient.enableCredentialSharingModeExtendedPANID, "deadbeef00112233")
        XCTAssertEqual(sut.state, .success)
    }

    func test_enableSharingMode_failure_reports_error() async {
        mockClient.enableCredentialSharingModeError = ThreadClientServiceError.credentialSharingModeUnavailable
        sut.extendedPANID = "deadbeef00112233"

        await sut.enableSharingMode()

        XCTAssertEqual(
            sut.state,
            .failure(ThreadClientServiceError.credentialSharingModeUnavailable.localizedDescription)
        )
        XCTAssertTrue(sut.canEnableSharingMode)
    }

    func test_select_is_ignored_while_request_is_in_flight() async {
        mockClient.suspendEnableCredentialSharingMode = true
        sut.extendedPANID = "deadbeef00112233"
        let request = Task { await sut.enableSharingMode() }
        let deadline = Date().addingTimeInterval(5)
        while !mockClient.hasSuspendedEnableCredentialSharingModeRequests, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        guard mockClient.hasSuspendedEnableCredentialSharingModeRequests else {
            request.cancel()
            XCTFail("The sharing request never reached the client")
            return
        }
        XCTAssertEqual(sut.state, .loading)

        sut.select(ThreadCredential(
            networkName: "Other",
            networkKey: "key",
            extendedPANID: "0011223344556677",
            borderAgentID: "agent",
            macExtendedAddress: "mac",
            activeOperationalDataSet: "dataset",
            pskc: "pskc",
            channel: 25,
            panID: "pan"
        ))

        XCTAssertEqual(sut.extendedPANID, "deadbeef00112233")
        XCTAssertEqual(sut.state, .loading)
        XCTAssertFalse(sut.canEnableSharingMode)
        await sut.enableSharingMode()
        XCTAssertEqual(mockClient.enableCredentialSharingModeCallCount, 1)

        mockClient.resumeSuspendedEnableCredentialSharingModeRequests()
        await request.value

        XCTAssertEqual(sut.state, .success)
        XCTAssertEqual(mockClient.enableCredentialSharingModeExtendedPANID, "deadbeef00112233")
    }

    func test_seeded_credentials_skip_loading() async {
        sut = .init(threadClientService: mockClient, credentials: [], state: .success)
        XCTAssertFalse(sut.isLoadingCredentials)

        await sut.loadCredentialsIfNeeded()

        XCTAssertFalse(mockClient.retrieveAllCredentialsCalled)
        XCTAssertEqual(sut.state, .success)

        sut = .init(threadClientService: mockClient)
        await sut.loadCredentialsIfNeeded()

        XCTAssertTrue(mockClient.retrieveAllCredentialsCalled)
        XCTAssertEqual(sut.credentials.count, 2)
    }

    func test_enableSharingMode_with_invalid_id_does_nothing() async {
        sut.extendedPANID = "nope"

        await sut.enableSharingMode()

        XCTAssertNil(mockClient.enableCredentialSharingModeExtendedPANID)
        XCTAssertEqual(sut.state, .idle)
    }
}
