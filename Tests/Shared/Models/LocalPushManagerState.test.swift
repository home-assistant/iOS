import Foundation
@testable import Shared
import Testing

/// The local push connection state: counting received messages and surviving a Codable round trip.
struct LocalPushManagerStateTests {
    @Test func incrementingStartsCountingFromAnyState() {
        var state = LocalPushManager.State.establishing
        state.increment()
        #expect(state == .available(received: 1))
        state.increment(by: 2)
        #expect(state == .available(received: 3))
        var unavailable = LocalPushManager.State.unavailable
        unavailable.increment(by: 5)
        #expect(unavailable == .available(received: 5))
    }

    @Test func statesRoundTripThroughCodable() throws {
        for state: LocalPushManager.State in [.establishing, .unavailable, .available(received: 7)] {
            let decoded = try JSONDecoder().decode(
                LocalPushManager.State.self,
                from: JSONEncoder().encode(state)
            )
            #expect(decoded == state)
        }
    }
}
