#if os(iOS)
import Foundation
@testable import Shared
import Testing

struct WatchConnectivityWatchStateDerivedValuesTests {
    private typealias WatchState = HAWatchConnectivity.WatchState

    @Test func notPairedHasNothingInstalledOrEnabled() {
        let state = WatchState.notPaired
        #expect(state.appState == .notInstalled)
        #expect(state.complicationState == .notEnabled)
        #expect(state.numberOfComplicationUpdatesAvailableToday == 0)
    }

    @Test func pairedWithoutTheAppHasNoComplicationBudget() {
        let state = WatchState.paired(.notInstalled)
        #expect(state.appState == .notInstalled)
        #expect(state.complicationState == .notEnabled)
        #expect(state.numberOfComplicationUpdatesAvailableToday == 0)
    }

    @Test func installedWithoutComplicationHasNoBudget() {
        let url = URL(fileURLWithPath: "/tmp/watch")
        let state = WatchState.paired(.installed(.notEnabled, url))
        #expect(state.appState == .installed(.notEnabled, url))
        #expect(state.complicationState == .notEnabled)
        #expect(state.numberOfComplicationUpdatesAvailableToday == 0)
    }

    @Test func enabledComplicationReportsItsBudget() {
        let state = WatchState.paired(.installed(.enabled(numberOfUpdatesAvailableToday: 42), nil))
        #expect(state.complicationState == .enabled(numberOfUpdatesAvailableToday: 42))
        #expect(state.numberOfComplicationUpdatesAvailableToday == 42)
    }
}
#endif
