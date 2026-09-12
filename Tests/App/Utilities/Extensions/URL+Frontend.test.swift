import Foundation
@testable import HomeAssistant
import Testing

struct URLFrontendTests {
    /// The app injects `external_auth=1` as the *first* parameter, so removing it as text takes the `?`
    /// with it and glues what follows onto the path.
    @Test func dropsExternalAuthWithoutTakingTheQuerySeparator() throws {
        let url = try #require(URL(
            string: "https://ext.example.com/config/dashboard?external_auth=1&more-info-entity-id=update.core"
        ))

        #expect(
            url.droppingExternalAuthQueryItem?.absoluteString ==
                "https://ext.example.com/config/dashboard?more-info-entity-id=update.core"
        )
    }

    @Test func dropsTheWholeQueryWhenOnlyExternalAuthWasPresent() throws {
        let url = try #require(URL(string: "https://ext.example.com/lovelace/0?external_auth=1"))

        #expect(url.droppingExternalAuthQueryItem?.absoluteString == "https://ext.example.com/lovelace/0")
    }

    @Test func keepsAQueryThatNeverCarriedExternalAuth() throws {
        let url = try #require(URL(string: "http://home.local:8123/history?back=1#anchor"))

        #expect(
            url.droppingExternalAuthQueryItem?.absoluteString == "http://home.local:8123/history?back=1#anchor"
        )
    }

    /// Values keep their percent-encoding: decoding and re-encoding them through `queryItems` mangles
    /// the reserved characters a parameter may carry.
    @Test func preservesPercentEncodingOfTheRemainingParameters() throws {
        let url = try #require(URL(string: "https://ext.example.com/lovelace/0?external_auth=1&filter=a%26b%20c"))

        #expect(
            url.droppingExternalAuthQueryItem?.absoluteString == "https://ext.example.com/lovelace/0?filter=a%26b%20c"
        )
    }

    @Test func relativeReferenceKeepsPathQueryAndFragmentWithoutTheHost() throws {
        let url = try #require(URL(string: "https://ext.example.com:8123/history?back=1#anchor"))

        #expect(url.relativeReference == "/history?back=1#anchor")
    }

    @Test func relativeReferenceFallsBackToTheRootPath() throws {
        let url = try #require(URL(string: "https://ext.example.com:8123"))

        #expect(url.relativeReference == "/")
    }

    @Test func relativeReferenceStaysPercentEncoded() throws {
        let url = try #require(URL(string: "https://ext.example.com/lovelace/my%20view?name=a%20b"))

        #expect(url.relativeReference == "/lovelace/my%20view?name=a%20b")
    }
}
