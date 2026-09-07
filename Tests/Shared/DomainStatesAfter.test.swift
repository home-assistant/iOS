@testable import Shared
import Testing

/// The state a confirmation waits for after each service, so a card reports what the action
/// produced rather than the state it replaced.
struct DomainStatesAfterTests {
    @Test func eachServiceNamesTheStatesItProduces() {
        #expect(Domain.light.statesAfter(.turnOn) == ["on"])
        #expect(Domain.light.statesAfter(.turnOff) == ["off"])
        #expect(Domain.switch.statesAfter(.turnOn) == ["on"])
        #expect(Domain.cover.statesAfter(.openCover) == ["open", "opening"])
        #expect(Domain.cover.statesAfter(.closeCover) == ["closed", "closing"])
        #expect(Domain.valve.statesAfter(.openValve) == ["open", "opening"])
        #expect(Domain.valve.statesAfter(.closeValve) == ["closed", "closing"])
        #expect(Domain.lock.statesAfter(.lock) == ["locked", "locking"])
        #expect(Domain.lock.statesAfter(.unlock) == ["unlocked", "unlocking"])
    }

    /// A curtain travels for far longer than a card will wait, so the state it holds while moving
    /// has to count: it already proves the command landed. Without it the card reads "Open" for
    /// the whole of a close.
    @Test func whatMovesCountsAsSoonAsItStartsMoving() {
        #expect(Domain.cover.statesAfter(.closeCover).contains("closing"))
        #expect(Domain.cover.statesAfter(.openCover).contains("opening"))
        #expect(Domain.lock.statesAfter(.lock).contains("locking"))
        #expect(Domain.valve.statesAfter(.closeValve).contains("closing"))
    }

    /// The state a toggle reads as off has to be one the off services produce, or a card would
    /// wait for a state the entity never reports.
    @Test func theOffStatesAreTheOnesAToggleReadsAsOff() {
        let offStates = [
            Domain.light.statesAfter(.turnOff),
            Domain.cover.statesAfter(.closeCover),
            Domain.lock.statesAfter(.lock),
        ]
        #expect(offStates.allSatisfy { $0.contains(where: Domain.statesOff.contains) })
    }

    /// A scene and a button record the time they last ran, and a script only reads `on` while it
    /// is running — waiting on any of those would just spend the deadline.
    @Test func whatRunsRatherThanChangesWaitsForNothing() {
        #expect(Domain.scene.statesAfter(.turnOn).isEmpty)
        #expect(Domain.script.statesAfter(.turnOn).isEmpty)
        #expect(Domain.button.statesAfter(.press).isEmpty)
        #expect(Domain.inputButton.statesAfter(.press).isEmpty)
    }

    /// A service that changes an attribute leaves the state alone, so there is nothing to wait for.
    @Test func aServiceThatChangesNoStateWaitsForNothing() {
        #expect(Domain.climate.statesAfter(.setTemperature).isEmpty)
        #expect(Domain.light.statesAfter(.toggle).isEmpty)
        #expect(Domain.cover.statesAfter(.setCoverPosition).isEmpty)
    }
}
