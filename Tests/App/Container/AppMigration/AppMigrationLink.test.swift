@testable import HomeAssistant
@testable import Shared
import Foundation
import Testing

struct AppMigrationLinkTests {
    @Test func roundTripsAChunkThroughAHandoffURL() throws {
        let chunk = AppMigrationChunk(sessionID: "session", index: 1, total: 3, data: "slice")

        let url = try #require(AppMigrationLink.importURL(chunk: chunk))

        #expect(url.scheme == AppMigrationConstants.destinationURLScheme)
        #expect(AppMigrationLink.importChunk(from: url) == chunk)
    }

    /// The payload rides in the fragment, never the query: a fragment is not sent to a web server, so
    /// the Safari fallback for an uninstalled app cannot leak the credentials it carries.
    @Test func carriesThePayloadInTheFragment() throws {
        let chunk = AppMigrationChunk(sessionID: "session", index: 0, total: 1, data: "secret")

        let url = try #require(AppMigrationLink.importURL(chunk: chunk))

        #expect(url.fragment?.contains("secret") == true)
        #expect(url.query == nil)
    }

    @Test func roundTripsAContinuationRequest() throws {
        let url = try #require(AppMigrationLink.continueURL(sessionID: "session", nextIndex: 4))

        let continuation = try #require(AppMigrationLink.continuation(from: url))

        #expect(url.scheme == AppMigrationConstants.sourceURLScheme)
        #expect(continuation.sessionID == "session")
        #expect(continuation.nextIndex == 4)
    }

    @Test func roundTripsAnAcknowledgement() throws {
        let url = try #require(AppMigrationLink.completionURL(importedServerCount: 3))

        #expect(url.scheme == AppMigrationConstants.sourceURLScheme)
        #expect(AppMigrationLink.completedServerCount(from: url) == 3)
    }

    /// The three URL kinds share the source scheme, so each parser has to ignore the other two rather
    /// than half-matching one.
    @Test func doesNotConfuseTheThreeKindsOfLink() throws {
        let handoff = try #require(
            AppMigrationLink.importURL(chunk: .init(sessionID: "s", index: 0, total: 1, data: "d"))
        )
        let continuation = try #require(AppMigrationLink.continueURL(sessionID: "s", nextIndex: 1))
        let completion = try #require(AppMigrationLink.completionURL(importedServerCount: 1))

        #expect(AppMigrationLink.continuation(from: handoff) == nil)
        #expect(AppMigrationLink.completedServerCount(from: handoff) == nil)
        #expect(AppMigrationLink.importChunk(from: continuation) == nil)
        #expect(AppMigrationLink.completedServerCount(from: continuation) == nil)
        #expect(AppMigrationLink.importChunk(from: completion) == nil)
        #expect(AppMigrationLink.continuation(from: completion) == nil)
    }

    @Test(arguments: [
        "https://example.com/migrate#data",
        "homeassistant://navigate/lovelace",
        "homeassistant://migration-continue",
    ]) func ignoresUnrelatedURLs(_ string: String) throws {
        let url = try #require(URL(string: string))

        #expect(AppMigrationLink.importChunk(from: url) == nil)
        #expect(AppMigrationLink.continuation(from: url) == nil)
    }
}
