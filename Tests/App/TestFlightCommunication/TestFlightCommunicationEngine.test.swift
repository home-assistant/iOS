@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct TestFlightCommunicationEngineTests {
    private let seenTestFlightMessageIDsKey = "seenTestFlightMessageIDs"

    @Test func messageToShowReturnsFirstUnseenMessageForCurrentPlatform() {
        let firstMessage = Self.message(id: .init("first"), targetPlatforms: [.iPhone, .iPad])
        let secondMessage = Self.message(id: .init("second"), targetPlatforms: [.iPhone])

        let engine = TestFlightCommunicationEngine(
            messages: [firstMessage, secondMessage],
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            hasSeenMessage: { _ in false }
        )

        #expect(engine.messageToShow() == firstMessage)
    }

    @Test func messageToShowSkipsSeenMessagesAndReturnsNextUnseen() {
        let seenMessage = Self.message(id: .init("seen"), targetPlatforms: [.iPhone])
        let unseenMessage = Self.message(id: .init("unseen"), targetPlatforms: [.iPhone])

        let engine = TestFlightCommunicationEngine(
            messages: [seenMessage, unseenMessage],
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            hasSeenMessage: { $0 == "seen" }
        )

        #expect(engine.messageToShow() == unseenMessage)
    }

    @Test func messageToShowReturnsNilWhenNotOnTestFlight() {
        let message = Self.message(id: .init("msg"), targetPlatforms: [.iPhone])

        let engine = TestFlightCommunicationEngine(
            messages: [message],
            isTestFlight: { false },
            currentPlatform: { .iPhone },
            hasSeenMessage: { _ in false }
        )

        #expect(engine.messageToShow() == nil)
    }

    @Test func messageToShowReturnsNilWhenPlatformDoesNotMatch() {
        let message = Self.message(id: .init("mac-only"), targetPlatforms: [.mac])

        let engine = TestFlightCommunicationEngine(
            messages: [message],
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            hasSeenMessage: { _ in false }
        )

        #expect(engine.messageToShow() == nil)
    }

    @Test func messageToShowReturnsNilWhenAllMessagesAreSeen() {
        let message = Self.message(id: .init("seen"), targetPlatforms: [.iPhone])

        let engine = TestFlightCommunicationEngine(
            messages: [message],
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            hasSeenMessage: { _ in true }
        )

        #expect(engine.messageToShow() == nil)
    }

    @Test func latestMessageReturnsLastMessageForCurrentPlatform() {
        let firstMessage = Self.message(id: .init("first"), targetPlatforms: [.iPhone])
        let latestMessage = Self.message(id: .init("latest"), targetPlatforms: [.iPhone, .iPad])
        let macOnlyMessage = Self.message(id: .init("mac"), targetPlatforms: [.mac])

        let engine = TestFlightCommunicationEngine(
            messages: [firstMessage, latestMessage, macOnlyMessage],
            isTestFlight: { true },
            currentPlatform: { .iPad },
            hasSeenMessage: { _ in true }
        )

        #expect(engine.latestMessage() == latestMessage)
    }

    @Test func latestMessageReturnsNilWhenNotOnTestFlight() {
        let message = Self.message(id: .init("msg"), targetPlatforms: [.iPhone])

        let engine = TestFlightCommunicationEngine(
            messages: [message],
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
