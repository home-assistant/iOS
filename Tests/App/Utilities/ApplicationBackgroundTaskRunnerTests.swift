import Foundation
@testable import HomeAssistant
import PromiseKit
import Testing
import UIKit

/// The app's background task runner wraps work in a `UIApplication` background task, both from the
/// main thread and from a background thread (which reads the remaining time on the main thread).
@MainActor
struct ApplicationBackgroundTaskRunnerTests {
    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Int?
        var value: Int? { lock.withLock { stored } }
        func set(_ value: Int) { lock.withLock { stored = value } }
    }

    /// The result arrives through several PromiseKit hops onto the main queue, which other suites
    /// keep busy under load, so the deadline counts main-queue turns as well as time.
    private func wait(for box: Box) async -> Int? {
        _ = await LoadTolerantDeadline.waitUntil { box.value != nil }
        return box.value
    }

    @Test func runsWorkFromTheMainThread() async {
        let runner = ApplicationBackgroundTaskRunner()
        let box = Box()
        runner(withName: "test-main", requiringAssertion: false) { _ in .value(42) }
            .done { box.set($0) }
            .cauterize()
        await #expect(wait(for: box) == 42)
    }

    @Test func runsWorkFromABackgroundThread() async {
        let box = Box()
        DispatchQueue.global().async {
            ApplicationBackgroundTaskRunner()(withName: "test-background", requiringAssertion: true) { _ in
                .value(7)
            }
            .done { box.set($0) }
            .cauterize()
        }
        await #expect(wait(for: box) == 7)
    }
}
