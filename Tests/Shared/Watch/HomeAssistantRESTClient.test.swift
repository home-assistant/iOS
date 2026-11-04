import Foundation
@testable import Shared
import Testing

struct HomeAssistantRESTClientTests {
    private let base = URL(string: "https://example.com:8123")!

    @Test func buildsAPIPathFromComponents() throws {
        let url = try HomeAssistantRESTClient.url(base: base, path: ["services", "light", "turn_on"])

        #expect(url.absoluteString == "https://example.com:8123/api/services/light/turn_on")
    }

    @Test func keepsSubpathOfTheServerURL() throws {
        let url = try HomeAssistantRESTClient.url(
            base: URL(string: "https://example.com/ha")!,
            path: ["states"]
        )

        #expect(url.absoluteString == "https://example.com/ha/api/states")
    }

    @Test func appendsValuelessFlagQuery() throws {
        let url = try HomeAssistantRESTClient.url(
            base: base,
            path: ["services", "calendar", "get_events"],
            query: [URLQueryItem(name: "return_response", value: nil)]
        )

        #expect(url.absoluteString == "https://example.com:8123/api/services/calendar/get_events?return_response")
    }
}
