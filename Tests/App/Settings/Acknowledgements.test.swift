import Foundation
@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
import SharedTesting
import SwiftUI
import Testing

/// The acknowledgements screen lists the app's Swift packages from the bundled `Package.resolved`
/// and shows each one's license, fetched from GitHub (stubbed here) at the pinned revision.
/// Shared state: installs a process-wide HTTP stub for raw.githubusercontent.com.
@MainActor
@Suite(.sharedState)
struct AcknowledgementsTests {
    private static func package(_ repository: String, revision: String?) throws -> AcknowledgementPackage {
        let revisionJSON = revision.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"package": "Package", "repositoryURL": "\(repository)", "state": {"revision": \(revisionJSON)}}
        """
        return try JSONDecoder().decode(AcknowledgementPackage.self, from: Data(json.utf8))
    }

    @Test func licensesAreLookedUpOnGitHubAtThePinnedRevision() throws {
        let package = try Self.package("https://github.com/home-assistant/HAKit.git", revision: "abc123")
        #expect(package.id == package.repositoryURL)
        #expect(package.displayName == "HAKit")
        #expect(package.licenseURLs.count == 4)
        #expect(
            package.licenseURLs.first?.absoluteString ==
                "https://raw.githubusercontent.com/home-assistant/HAKit/abc123/LICENSE"
        )

        let notGitHub = try Self.package("https://gitlab.com/owner/repo.git", revision: "abc")
        let unpinned = try Self.package("https://github.com/owner/repo.git", revision: nil)
        let ownerOnly = try Self.package("https://github.com/owner", revision: "abc")
        #expect(notGitHub.licenseURLs.isEmpty)
        #expect(unpinned.licenseURLs.isEmpty)
        #expect(ownerOnly.licenseURLs.isEmpty)
    }

    /// The first license file that answers with text wins; error pages, failures and HTML are skipped.
    @Test func theFirstLicenseFileThatAnswersWins() async throws {
        let descriptor = stub(condition: isHost("raw.githubusercontent.com")) { request in
            switch request.url?.lastPathComponent {
            case "LICENSE":
                return HTTPStubsResponse(error: URLError(.notConnectedToInternet))
            case "LICENSE.md":
                return HTTPStubsResponse(data: Data("Not found".utf8), statusCode: 404, headers: nil)
            case "LICENSE.txt":
                return HTTPStubsResponse(data: Data("<!DOCTYPE html><html/>".utf8), statusCode: 200, headers: nil)
            default:
                return HTTPStubsResponse(data: Data("MIT License".utf8), statusCode: 200, headers: nil)
            }
        }
        defer { HTTPStubs.removeStub(descriptor) }

        let package = try Self.package("https://github.com/home-assistant/HAKit.git", revision: "abc123")
        let license = await package.loadLicenseText()
        #expect(license == "MIT License")

        let unlicensed = try Self.package("https://example.com/owner/repo.git", revision: "abc")
        let none = await unlicensed.loadLicenseText()
        #expect(none == nil)
    }

    /// The list opens each package's license screen, which loads the license text.
    @Test func theListOpensALicense() async throws {
        let requests = RequestCounter()
        let descriptor = stub(condition: isHost("raw.githubusercontent.com")) { _ in
            requests.increment()
            return HTTPStubsResponse(data: Data("Apache License".utf8), statusCode: 200, headers: nil)
        }
        defer { HTTPStubs.removeStub(descriptor) }

        let packages = AcknowledgementPackage.load()
        try #require(!packages.isEmpty)
        let driver = await SwiftUIScreenDriver.show(AcknowledgementsView())
        defer { driver.close() }
        #expect(driver.rowCount(inSection: 0) == packages.count)

        try await #require(driver.push(IndexPath(item: 0, section: 0)))
        await #expect(driver.waitUntil { requests.count > 0 })
        await driver.settle(5)
    }
}

/// Counts stubbed requests, which arrive on URLSession's queue.
private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}
