import Foundation
@testable import Shared
import Testing

struct WatchServiceCallSenderTests {
    @Test func payloadMergesEntityIdIntoData() {
        let payload = WatchServiceCallSender.payload(
            entityId: "light.kitchen",
            data: ["brightness_pct": 40]
        )

        #expect(payload["entity_id"] as? String == "light.kitchen")
        #expect(payload["brightness_pct"] as? Int == 40)
    }

    @Test func payloadEntityIdWinsOverDataEntry() {
        let payload = WatchServiceCallSender.payload(
            entityId: "light.kitchen",
            data: ["entity_id": "light.other"]
        )

        #expect(payload["entity_id"] as? String == "light.kitchen")
    }
}
