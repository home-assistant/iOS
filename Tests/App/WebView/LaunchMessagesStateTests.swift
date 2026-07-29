@testable import HomeAssistant
@testable import Shared
import SFSafeSymbols
import XCTest

@MainActor
final class LaunchMessagesStateTests: XCTestCase {
    func testDismissAllClearsThePresentedMessage() {
        let sut = LaunchMessagesState()
        sut.presented = .whatsNew(Self.release())

        sut.dismissAll()

        XCTAssertNil(sut.presented)
    }

    /// The launch-message sheet calls `showNext()` from `onDismiss`, so dropping only the presented message
    /// would immediately cover whatever an incoming deep link just navigated to.
    func testDismissAllStopsTheQueueFromRePresenting() {
        let sut = LaunchMessagesState()
        sut.presented = .whatsNew(Self.release(id: "first"))
        sut.pending = [.whatsNew(Self.release(id: "second"))]

        sut.dismissAll()
        sut.showNext()

        XCTAssertNil(sut.presented)
        XCTAssertTrue(sut.pending.isEmpty)
    }

    private static func release(id: String = "test-release") -> WhatsNewRelease {
        WhatsNewRelease(
            id: WhatsNewReleaseId(id),
            version: WhatsNewAppVersion(major: 2026, minor: 1, patch: 0),
            targetPlatforms: [.iPhone],
            items: [
                WhatsNewItem(
                    id: "item",
                    title: "A change",
                    body: "A user-facing change.",
                    icon: .sfSymbol(.checkmark)
                ),
            ]
        )
    }
}
