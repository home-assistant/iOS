@testable import HomeAssistant
import XCTest

@available(iOS 13, *)
final class ThreadCredentialsSharingViewModelTests: XCTestCase {
    private var sut: ThreadCredentialsSharingViewModel!
    private var mockClient: MockThreadClientService!

    override func setUpWithError() throws {
        mockClient = MockThreadClientService()
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
        await sut.retrieveAllCredentials()

        // Then
        XCTAssertTrue(mockClient.retrieveAllCredentialsCalled)
        XCTAssertEqual(sut.credentials.count, 2)
    }
}
