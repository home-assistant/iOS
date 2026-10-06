import Foundation
import HAKit
import HAKit_Mocks
@testable import Shared
import Testing

struct AppIntentServerAPICallActionTests {
    @Test func aCallTheServerNeverAnswersTimesOutAndIsCancelled() async {
        let connection = HAMockConnection()

        await #expect(throws: ShortcutAppIntentError.self) {
            try await AppIntentServerAPI.callActionViaWebSocket(
                on: connection,
                domain: "cover",
                service: "close_cover",
                data: ["entity_id": "cover.living_room"],
                returnResponse: false,
                timeout: 0.05
            )
        }

        #expect(connection.cancelledRequests.map(\.type.command) == ["call_service"])
    }

    @Test func anAnsweredCallReturnsTheResponseAndIsNotCancelled() async throws {
        let connection = HAMockConnection()

        let call = Task {
            try await AppIntentServerAPI.callActionViaWebSocket(
                on: connection,
                domain: "script",
                service: "good_morning",
                data: [:],
                returnResponse: true,
                timeout: 5
            )
        }
        var waited = 0
        while connection.pendingRequests.isEmpty, waited < 300 {
            try await Task.sleep(nanoseconds: 5_000_000)
            waited += 1
        }
        let pending = try #require(connection.pendingRequests.first)
        pending.completion(.success(.dictionary(["response": ["greeting": "Good morning"]])))

        let response = try await call.value

        #expect(pending.request.data["domain"] as? String == "script")
        #expect(pending.request.data["service"] as? String == "good_morning")
        #expect(response.hasResponse)
        #expect(connection.cancelledRequests.isEmpty)
    }
}
