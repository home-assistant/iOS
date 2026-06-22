@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct TestFlightCommunicationEngineTests {
    private let seenTestFlightMessageIDsKey = "seenTestFlightMessageIDs"

    @Test func messageToShowReturnsMessageForCurrentPlatform() {
        let message = Self.message(id: .init("msg"), targetPlatforms: [.iPhone, .iPad])

        let engine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            hasSeenMessage: { _ in false }
        )

        #expect(engine.messageToShow() == message)
    }

    @Test func messageToShowReturnsNilWhenNoMessageIsConfigured() {
        let engine = TestFlightCommunicationEngine(
            message: nil,
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            hasSeenMessage: { _ in false }
        )

        #expect(engine.messageToShow() == nil)
    }

    @Test func messageToShowReturnsNilWhenMessageWasSeen() {
        let message = Self.message(id: .init("seen"), targetPlatforms: [.iPhone])

        let engine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            hasSeenMessage: { $0 == "seen" }
        )

        #expect(engine.messageToShow() == nil)
    }

    @Test func messageToShowReturnsNilWhenNotOnTestFlight() {
        let message = Self.message(id: .init("msg"), targetPlatforms: [.iPhone])

        let engine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { false },
            currentPlatform: { .iPhone },
            hasSeenMessage: { _ in false }
        )

        #expect(engine.messageToShow() == nil)
    }

    @Test func messageToShowReturnsNilWhenPlatformDoesNotMatch() {
        let message = Self.message(id: .init("mac-only"), targetPlatforms: [.mac])

        let engine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            hasSeenMessage: { _ in false }
        )

        #expect(engine.messageToShow() == nil)
    }

    @Test func latestMessageReturnsMessageForCurrentPlatformIgnoringSeenState() {
        let message = Self.message(id: .init("latest"), targetPlatforms: [.iPhone, .iPad])

        let engine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { true },
            currentPlatform: { .iPad },
            hasSeenMessage: { _ in true }
        )

        #expect(engine.latestMessage() == message)
    }

    @Test func latestMessageReturnsNilWhenPlatformDoesNotMatch() {
        let message = Self.message(id: .init("mac-only"), targetPlatforms: [.mac])

        let engine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { true },
            currentPlatform: { .iPad },
            hasSeenMessage: { _ in true }
        )

        #expect(engine.latestMessage() == nil)
    }

    @Test func latestMessageReturnsNilWhenNotOnTestFlight() {
        let message = Self.message(id: .init("msg"), targetPlatforms: [.iPhone])

        let engine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { false },
            currentPlatform: { .iPhone },
            hasSeenMessage: { _ in false }
        )

        #expect(engine.latestMessage() == nil)
    }

    @Test func settingsStorePersistsSeenMessageIDsWithoutDroppingExistingValues() {
        Current.settingsStore.prefs.removeObject(forKey: seenTestFlightMessageIDsKey)
        defer { Current.settingsStore.prefs.removeObject(forKey: seenTestFlightMessageIDsKey) }

        Current.settingsStore.markTestFlightMessageSeen(messageID: "beta-v1")
        Current.settingsStore.markTestFlightMessageSeen(messageID: "beta-v2")

        #expect(Current.settingsStore.hasSeenTestFlightMessage(messageID: "beta-v1"))
        #expect(Current.settingsStore.hasSeenTestFlightMessage(messageID: "beta-v2"))
        #expect(!Current.settingsStore.hasSeenTestFlightMessage(messageID: "beta-v3"))
    }

    private static func message(
        id: TestFlightMessageId,
        targetPlatforms: [WhatsNewTargetPlatform]
    ) -> TestFlightMessage {
        TestFlightMessage(
            id: id,
            title: "Beta update",
            items: [
                WhatsNewItem(
                    id: .whatsNewValidationIntro,
                    title: "What to test",
                    body: "Something new to validate.",
                    icon: .sfSymbol(.checkmark)
                ),
            ],
            targetPlatforms: targetPlatforms
        )
    }
}
