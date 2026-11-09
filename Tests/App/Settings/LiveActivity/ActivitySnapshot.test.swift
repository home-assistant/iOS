#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
@testable import HomeAssistant
import Shared
import Testing

struct ActivitySnapshotTests {
    @available(iOS 17.2, *)
    @Test func dynamicTitleOverridesOriginalTitle() {
        let attributes = HALiveActivityAttributes(tag: "laundry-room", title: "Laundry")
        let snapshot = ActivitySnapshot(
            id: "activity-42",
            attributes: attributes,
            state: HALiveActivityAttributes.ContentState(message: "Cycle finished", title: "Laundry done")
        )

        #expect(snapshot.id == "activity-42")
        #expect(snapshot.tag == "laundry-room")
        #expect(snapshot.title == "Laundry done")
        #expect(snapshot.message == "Cycle finished")
    }

    @available(iOS 17.2, *)
    @Test func missingDynamicTitleFallsBackToOriginalTitle() {
        let attributes = HALiveActivityAttributes(tag: "laundry-room", title: "Laundry")
        let snapshot = ActivitySnapshot(
            id: "activity-42",
            attributes: attributes,
            state: HALiveActivityAttributes.ContentState(message: "Cycle running")
        )

        #expect(snapshot.id == "activity-42")
        #expect(snapshot.tag == "laundry-room")
        #expect(snapshot.title == "Laundry")
        #expect(snapshot.message == "Cycle running")
    }

    @available(iOS 17.2, *)
    @Test(arguments: [
        ("missing", #"{"message":"Cycle running"}"#),
        ("null", #"{"message":"Cycle running","title":null}"#),
        ("empty", #"{"message":"Cycle running","title":""}"#),
    ])
    func decodedStateWithoutTitleFallsBackToOriginalTitle(name: String, json: String) throws {
        let state = try JSONDecoder().decode(
            HALiveActivityAttributes.ContentState.self,
            from: Data(json.utf8)
        )
        let snapshot = ActivitySnapshot(
            id: "activity-42",
            attributes: HALiveActivityAttributes(tag: "laundry-room", title: "Laundry"),
            state: state
        )

        #expect(snapshot.title == "Laundry", "\(name) title")
        #expect(snapshot.message == "Cycle running")
    }
}
#endif
