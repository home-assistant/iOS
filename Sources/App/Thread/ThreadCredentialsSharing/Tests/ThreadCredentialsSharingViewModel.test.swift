@testable import HomeAssistant
@testable import Shared
import XCTest

final class ThreadTransferCredentialToHAViewModelTests: XCTestCase {
    private var sut: ThreadTransferCredentialToHAViewModel!
    private var mockClient: SimulatorThreadClientService!

    override func setUpWithError() throws {
        mockClient = SimulatorThreadClientService()
        sut = .init(
            server: ServerFixture.standard,
            threadClient: mockClient
        )
    }

    override func tearDownWithError() throws {
        sut = nil
        mockClient = nil
    }

    func test_retrieveAllCredentials_calls_retrieveAllCredentials() async {
        // When
        await sut.mainOperation()

        // Then
        XCTAssertTrue(mockClient.retrieveAllCredentialsCalled)
        XCTAssertEqual(sut.credentials.count, 2)
    }
}
