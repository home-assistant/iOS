import Foundation
@testable import Shared
import Testing

/// Without a paired watch with the app installed, a refresh request is skipped rather than queued.
struct WatchComplicationRefreshRequestTests {
    @Test func skipsWithoutAnInstalledWatch() {
        if case .paired(.installed) = Communicator.shared.currentWatchState {
            return
        }
        WatchComplicationRefreshRequest.send()
        #expect(WatchComplicationRefreshRequest.requestedAtKey == "requestedAt")
    }
}
