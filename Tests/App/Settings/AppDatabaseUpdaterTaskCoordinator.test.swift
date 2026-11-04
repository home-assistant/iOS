import Foundation
@testable import Shared
import Testing

/// Covers the finish broadcast the Sync button waits on: a queued update that is discarded before it
/// ever runs must still report itself as finished, or the button stays disabled.
struct AppDatabaseUpdaterTaskCoordinatorTests {
    @Test func discardedQueueEntriesReportFinishing() async throws {
        let coordinator = AppDatabaseUpdater.TaskCoordinator()
        let finished = FinishedServers()
        let observer = NotificationCenter.default.addObserver(
            forName: .appDatabaseUpdaterDidFinishServer,
            object: nil,
            queue: nil
        ) { notification in
            if let id = notification.userInfo?[AppDatabaseUpdaterUserInfo.serverIdentifierKey] as? String {
                finished.append(id)
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let blocker = Blocker()
        await coordinator.enqueueUpdate(serverId: "running", forceUpdate: true, showProgress: false) {
            await blocker.wait()
        }
        await coordinator.enqueueUpdate(serverId: "waiting", forceUpdate: true, showProgress: false) {}

        await coordinator.cancelAllTasks()
        await blocker.release()

        #expect(finished.ids == ["waiting"])
    }
}

private final class FinishedServers: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var ids: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ id: String) {
        lock.lock()
        storage.append(id)
        lock.unlock()
    }
}

/// Holds the first queued task open so the second one is still waiting when the queue is cancelled.
private actor Blocker {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        guard !released else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
