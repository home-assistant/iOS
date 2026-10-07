@testable import Shared
import Testing

struct WatchAreaControlsOrderTests {
    @Test func mostCommonDomainsSortFirst() {
        let lightIndex = Domain.watchAreaControlsSortIndex(for: .light)
        let switchIndex = Domain.watchAreaControlsSortIndex(for: .switch)
        let lockIndex = Domain.watchAreaControlsSortIndex(for: .lock)
        let automationIndex = Domain.watchAreaControlsSortIndex(for: .automation)

        #expect(lightIndex < switchIndex)
        #expect(switchIndex < lockIndex)
        #expect(lockIndex < automationIndex)
    }

    @Test func unknownDomainSortsLast() {
        let unlistedIndex = Domain.watchAreaControlsSortIndex(for: .sensor)
        let nilIndex = Domain.watchAreaControlsSortIndex(for: nil)
        let listedMaxIndex = Domain.watchAreaControlsSortIndex(for: .automation)

        #expect(unlistedIndex == Domain.watchAreaControlsOrder.count)
        #expect(nilIndex == Domain.watchAreaControlsOrder.count)
        #expect(listedMaxIndex < unlistedIndex)
    }

    @Test func everyRunnableWatchDomainIsListed() {
        let runnable = Set(Domain.watchSupported + Domain.controlScreenDomains)
        #expect(Set(Domain.watchAreaControlsOrder) == runnable)
    }
}
