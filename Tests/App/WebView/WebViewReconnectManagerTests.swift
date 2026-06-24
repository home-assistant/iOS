import Foundation
@testable import HomeAssistant
import XCTest

@MainActor
final class WebViewReconnectManagerTests: XCTestCase {
    func testSchedulesReconnectsUsingBackoffDelays() {
        let scheduler = RecordingScheduler()
        var reconnectCount = 0
        let sut = WebViewReconnectManager(
            isAppActive: { true },
            scheduleTimer: scheduler.schedule(delay:action:)
        )

        sut.start {
            reconnectCount += 1
        }

        XCTAssertEqual(scheduler.scheduledDelays, [10])

        scheduler.fireLast()
        XCTAssertEqual(reconnectCount, 1)
        XCTAssertEqual(scheduler.scheduledDelays, [10, 30])

        scheduler.fireLast()
        XCTAssertEqual(reconnectCount, 2)
        XCTAssertEqual(scheduler.scheduledDelays, [10, 30, 60])

        scheduler.fireLast()
        XCTAssertEqual(reconnectCount, 3)
        XCTAssertEqual(scheduler.scheduledDelays, [10, 30, 60, 600])

        scheduler.fireLast()
        XCTAssertEqual(reconnectCount, 4)
        XCTAssertEqual(scheduler.scheduledDelays, [10, 30, 60, 600, 600])
    }

    func testStopResetsBackoff() {
        let scheduler = RecordingScheduler()
        let sut = WebViewReconnectManager(
            isAppActive: { true },
            scheduleTimer: scheduler.schedule(delay:action:)
        )

        sut.start {}
        scheduler.fireLast()
        sut.stop()
        sut.start {}

        XCTAssertEqual(scheduler.scheduledDelays, [10, 30, 10])
    }

    func testInactiveAppDoesNotReconnectAndKeepsCurrentDelay() {
        let scheduler = RecordingScheduler()
        var isActive = false
        var reconnectCount = 0
        let sut = WebViewReconnectManager(
            isAppActive: { isActive },
            scheduleTimer: scheduler.schedule(delay:action:)
        )

        sut.start {
            reconnectCount += 1
        }
        scheduler.fireLast()

        XCTAssertEqual(reconnectCount, 0)
        XCTAssertEqual(scheduler.scheduledDelays, [10, 10])

        isActive = true
        scheduler.fireLast()

        XCTAssertEqual(reconnectCount, 1)
        XCTAssertEqual(scheduler.scheduledDelays, [10, 10, 30])
    }
}

@MainActor
private final class RecordingScheduler {
    struct ScheduledTimer {
        let delay: TimeInterval
        let action: @MainActor () -> Void
    }

    private(set) var timers = [ScheduledTimer]()

    var scheduledDelays: [TimeInterval] {
        timers.map(\.delay)
    }

    func schedule(delay: TimeInterval, action: @escaping @MainActor () -> Void) -> () -> Void {
        timers.append(ScheduledTimer(delay: delay, action: action))
        return {}
    }

    func fireLast() {
        timers.last?.action()
    }
}
