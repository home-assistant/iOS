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

    func test_enableSharingMode_with_invalid_id_does_nothing() async {
        sut.extendedPANID = "nope"

        await sut.enableSharingMode()

        XCTAssertNil(mockClient.enableCredentialSharingModeExtendedPANID)
        XCTAssertEqual(sut.state, .idle)
    }
}
