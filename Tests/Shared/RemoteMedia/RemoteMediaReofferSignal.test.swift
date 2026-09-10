import Foundation
@testable import Shared
import Testing

/// The host app's only way to say anything about registration, since the token it would register
/// never leaves the extension.
@MainActor
struct RemoteMediaReofferSignalTests {
    /// Its own defaults domain per test: the real one is shared with the running app, and these
    /// would otherwise leave a request behind for whatever reads it next.
    private func isolated(_ body: () -> Void) {
        let name = "RemoteMediaReofferSignalTests.\(UUID().uuidString)"
        let previous = RemoteMediaReofferSignal.defaults
        RemoteMediaReofferSignal.defaults = UserDefaults(suiteName: name)
        defer {
            UserDefaults().removePersistentDomain(forName: name)
            RemoteMediaReofferSignal.defaults = previous
        }
        body()
    }

    @Test func aRequestIsVisibleToWhateverReadsItNext() {
        isolated {
            let before = RemoteMediaReofferSignal.epoch
            RemoteMediaReofferSignal.request()
            #expect(RemoteMediaReofferSignal.epoch > before)
        }
    }

    /// The two processes do not overlap, so several launches can happen before the extension runs
    /// once. It has to be able to tell that it has missed something, not just that something
    /// happened.
    @Test func requestsAccumulateRatherThanToggling() {
        isolated {
            RemoteMediaReofferSignal.request()
            let once = RemoteMediaReofferSignal.epoch
            RemoteMediaReofferSignal.request()
            RemoteMediaReofferSignal.request()
            #expect(RemoteMediaReofferSignal.epoch > once)
        }
    }

    @Test func nothingFollowedLeavesNothingOutstanding() {
        isolated {
            RemoteMediaReofferSignal.request()
            RemoteMediaReofferSignal.clear()
            #expect(RemoteMediaReofferSignal.epoch == 0)
        }
    }
}
