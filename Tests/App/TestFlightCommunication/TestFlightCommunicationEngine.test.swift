@testable import HomeAssistant
@testable import Shared
import Testing
import Version

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

    @Test func messageToShowRespectsAppVersionWhenSpecified() {
        let message = Self.message(
            id: .init("versioned"),
            targetPlatforms: [.iPhone],
            version: .init(major: 2026, minor: 6, patch: 1)
        )

        let matchingEngine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            currentVersion: { Version(major: 2026, minor: 6, patch: 1) },
            currentOSVersion: { WhatsNewOSVersion(major: 26) },
            hasSeenMessage: { _ in false }
        )
        #expect(matchingEngine.messageToShow() == message)

        let mismatchedEngine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            currentVersion: { Version(major: 2026, minor: 6, patch: 0) },
            currentOSVersion: { WhatsNewOSVersion(major: 26) },
            hasSeenMessage: { _ in false }
        )
        #expect(mismatchedEngine.messageToShow() == nil)
    }

    @Test func messageToShowRespectsOSRequirementsWhenSpecified() {
        let message = Self.message(
            id: .init("os-gated"),
            targetPlatforms: [.iPhone],
            osRequirements: WhatsNewOSRequirements(iOS: WhatsNewOSVersionRange(minimum: WhatsNewOSVersion(major: 26)))
        )

        let withinRangeEngine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            currentOSVersion: { WhatsNewOSVersion(major: 26, minor: 1) },
            hasSeenMessage: { _ in false }
        )
        #expect(withinRangeEngine.messageToShow() == message)

        let belowRangeEngine = TestFlightCommunicationEngine(
            message: message,
            isTestFlight: { true },
            currentPlatform: { .iPhone },
            currentOSVersion: { WhatsNewOSVersion(major: 18, minor: 4) },
            hasSeenMessage: { _ in false }
        )
        #expect(belowRangeEngine.messageToShow() == nil)
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
        targetPlatforms: [WhatsNewTargetPlatform],
        version: WhatsNewAppVersion? = nil,
        osRequirements: WhatsNewOSRequirements? = nil
    ) -> TestFlightMessage {
        TestFlightMessage(
            id: id,
            title: "Beta update",
            items: [
                WhatsNewItem(
                    id: "whatsNewValidationIntro",
                    title: "What to test",
                    body: "Something new to validate.",
                    icon: .sfSymbol(.checkmark)
                ),
            ],
            targetPlatforms: targetPlatforms,
            version: version,
            osRequirements: osRequirements
        )
    }
}
