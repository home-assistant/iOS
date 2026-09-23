import Foundation
@testable import Shared
import Testing

struct ServerRequestPerformerTests {
    private func request(timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://ha.example.com/api/states")!)
        request.timeoutInterval = timeout
        return request
    }

    private func configuration(timeout: TimeInterval) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        return configuration
    }

    /// Callers bound themselves in one of two places — entity polling on the request, complication
    /// refresh on the session — so the budget has to read both and believe the tighter one.
    @Test func budgetTakesTheTighterOfTheTwoBounds() {
        #expect(ServerRequestPerformer.budget(
            for: request(timeout: 4),
            configuration: configuration(timeout: 60)
        ) == 4)

        #expect(ServerRequestPerformer.budget(
            for: request(timeout: 60),
            configuration: configuration(timeout: 8)
        ) == 8)
    }

    @Test func budgetIsTheSharedValueWhenBothAgree() {
        #expect(ServerRequestPerformer.budget(
            for: request(timeout: 30),
            configuration: configuration(timeout: 30)
        ) == 30)
    }
}
