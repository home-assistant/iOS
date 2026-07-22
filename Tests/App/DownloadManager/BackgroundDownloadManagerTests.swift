import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

struct BackgroundDownloadManagerTests {
    @Test func testSessionIdentifierMatching() {
        let identifier = BackgroundDownloadManager.sessionIdentifier
        #expect(BackgroundDownloadManager.isManager(forSessionIdentifier: identifier))
        #expect(!BackgroundDownloadManager.isManager(forSessionIdentifier: "io.robbie.HomeAssistant.other"))
    }

    @Test func testDestinationURLLivesInDownloadsDirectory() throws {
        let url = try #require(BackgroundDownloadManager.destinationURL(forSuggestedFilename: "backup.tar"))
        #expect(url.lastPathComponent == "backup.tar")
        #expect(url.absoluteString.hasPrefix(AppConstants.DownloadsDirectory.absoluteString))
    }

    @Test func testDestinationURLEncodesUnsafeCharacters() throws {
        let url = try #require(BackgroundDownloadManager.destinationURL(forSuggestedFilename: "my backup.tar"))
        #expect(url.lastPathComponent == "my backup.tar")
    }

    @Test func testDestinationURLStripsPathTraversal() throws {
        let downloadsPrefix = AppConstants.DownloadsDirectory.absoluteString
        let traversal = try #require(BackgroundDownloadManager.destinationURL(forSuggestedFilename: "../evil.tar"))
        #expect(traversal.lastPathComponent == "evil.tar")
        #expect(traversal.absoluteString.hasPrefix(downloadsPrefix))

        let nested = try #require(BackgroundDownloadManager.destinationURL(forSuggestedFilename: "a/b/c.tar"))
        #expect(nested.lastPathComponent == "c.tar")
        #expect(nested.absoluteString.hasPrefix(downloadsPrefix))

        let bare = try #require(BackgroundDownloadManager.destinationURL(forSuggestedFilename: ".."))
        #expect(bare.lastPathComponent == "Unknown")
        #expect(bare.absoluteString.hasPrefix(downloadsPrefix))
    }

    @Test func testValidationErrorForSuccessResponse() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/file")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        #expect(BackgroundDownloadManager.validationError(for: response) == nil)
    }

    @Test func testValidationErrorForErrorResponse() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/file")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        #expect(BackgroundDownloadManager.validationError(for: response) != nil)
    }

    @Test func testValidationErrorForNonHTTPResponse() {
        #expect(BackgroundDownloadManager.validationError(for: nil) == nil)
    }
}
