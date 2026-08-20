@testable import HomeAssistant
@testable import Shared
import Testing

// The Focus Filter is not the only thing that reports a Focus name: iOS skips running it for a
// Focus that turns on by itself, and the user's own report — from a Shortcuts automation or the
// settings screen — is what corrects the sensor then. Both go through the reporter, so both have
// to record the same thing.
@Suite(.serialized)
@MainActor
struct FocusNameReporterTests {
    private final class Recorder {
        var names: [String?] = []
    }

    private func makeEnvironment() -> (recorder: Recorder, events: MockClientEventStore) {
        Current.servers = FakeServerManager(initial: 0)
        Current.focusFilter = FocusFilterWrapper()

        let recorder = Recorder()
        Current.focusFilter.setActiveFocusName = { recorder.names.append($0) }

        let events = MockClientEventStore(addEventAction: { _ in })
        Current.clientEventStore = events

        return (recorder, events)
    }

    @Test func reportStoresTheNameAndRecordsWhatReportedIt() async {
        let (recorder, events) = makeEnvironment()

        await FocusNameReporter.report(name: "Sleep", source: .manual)

        #expect(recorder.names == ["Sleep"])
        #expect(events.addedEvents.count == 1)
        #expect(events.addedEvents.first?.text == "Focus name reported: Sleep")
        #expect(events.addedEvents.first?.jsonPayloadJSONObject()["source"] as? String == "manual")
    }

    @Test func reportWithoutANameClearsWhatIsReported() async {
        let (recorder, events) = makeEnvironment()

        await FocusNameReporter.report(name: nil, source: .focusFilter)

        #expect(recorder.names == [String?.none])
        #expect(events.addedEvents.first?.text == "Focus name reported: none")
        #expect(events.addedEvents.first?.jsonPayloadJSONObject()["source"] as? String == "focus filter")
    }
}
